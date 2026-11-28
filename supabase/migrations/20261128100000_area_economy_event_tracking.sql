-- First-party AREA economy funnel and gifting analytics.
create table if not exists private.area_economy_events (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  event_name text not null check (event_name in ('wallet_view','package_impression','package_checkout_click','gift_transfer_attempt')),
  object_key text,
  created_at timestamptz not null default now(),
  constraint area_economy_events_object_key_length check (object_key is null or char_length(object_key) <= 64)
);
alter table private.area_economy_events enable row level security;
revoke all on private.area_economy_events from public, anon, authenticated;
create index if not exists area_economy_events_name_created_idx on private.area_economy_events(event_name,created_at desc);
create index if not exists area_economy_events_user_name_created_idx on private.area_economy_events(user_id,event_name,created_at desc);
create index if not exists area_economy_events_object_created_idx on private.area_economy_events(event_name,object_key,created_at desc);

create or replace function public.track_area_economy_event(p_event_name text,p_object_key text default null)
returns boolean
language plpgsql
security definer
set search_path=''
as $function$
declare
  v_user_id uuid := auth.uid();
  v_object_key text := nullif(btrim(p_object_key),'');
begin
  if v_user_id is null then raise exception 'Sign in required.'; end if;
  if p_event_name not in ('wallet_view','package_impression','package_checkout_click','gift_transfer_attempt') then
    raise exception 'Unsupported economy event.';
  end if;
  if v_object_key is not null and char_length(v_object_key)>64 then raise exception 'Invalid event key.'; end if;
  if p_event_name in ('package_impression','package_checkout_click') and v_object_key is null then
    raise exception 'Package events require a package key.';
  end if;
  if p_event_name not in ('package_impression','package_checkout_click') then v_object_key := null; end if;
  if exists (
    select 1 from private.area_economy_events
    where user_id=v_user_id and event_name=p_event_name
      and object_key is not distinct from v_object_key
      and created_at>now()-interval '15 seconds'
  ) then return false; end if;
  if (select count(*) from private.area_economy_events
      where user_id=v_user_id and created_at>now()-interval '1 minute')>=30 then
    raise exception 'Economy event rate limit reached.';
  end if;
  insert into private.area_economy_events(user_id,event_name,object_key)
  values(v_user_id,p_event_name,v_object_key);
  return true;
end;
$function$;
revoke all on function public.track_area_economy_event(text,text) from public,anon;
grant execute on function public.track_area_economy_event(text,text) to authenticated;

create or replace function public.get_area_economy_analytics()
returns jsonb
language plpgsql
security definer
set search_path=''
as $function$
declare v_result jsonb;
begin
  if not public.is_area_admin() then raise exception 'Owner access required.'; end if;
  select jsonb_build_object(
    'wallet_views_7d',(select count(*)::bigint from private.area_economy_events where event_name='wallet_view' and created_at>=now()-interval '7 days'),
    'wallet_views_30d',(select count(*)::bigint from private.area_economy_events where event_name='wallet_view' and created_at>=now()-interval '30 days'),
    'wallet_viewers_30d',(select count(distinct user_id)::bigint from private.area_economy_events where event_name='wallet_view' and created_at>=now()-interval '30 days'),
    'package_impressions_7d',(select count(*)::bigint from private.area_economy_events where event_name='package_impression' and created_at>=now()-interval '7 days'),
    'package_clicks_7d',(select count(*)::bigint from private.area_economy_events where event_name='package_checkout_click' and created_at>=now()-interval '7 days'),
    'package_funnel',coalesce((
      select jsonb_agg(jsonb_build_object(
        'package_key',k.package_key,
        'impressions_30d',coalesce(i.impressions,0),
        'clicks_30d',coalesce(c.clicks,0),
        'viewers_30d',coalesce(i.viewers,0),
        'clickers_30d',coalesce(c.clickers,0),
        'click_rate_percent',case when coalesce(i.viewers,0)=0 then 0 else round(100.0*coalesce(c.clickers,0)/i.viewers,1) end
      ) order by coalesce(i.impressions,0) desc,k.package_key)
      from (
        select package_key from public.area_ac_packages
        union
        select distinct object_key from private.area_economy_events
          where event_name in ('package_impression','package_checkout_click')
            and created_at>=now()-interval '30 days' and object_key is not null
      ) k
      left join lateral (
        select count(*)::bigint impressions,count(distinct user_id)::bigint viewers
        from private.area_economy_events e
        where e.event_name='package_impression' and e.object_key=k.package_key and e.created_at>=now()-interval '30 days'
      ) i on true
      left join lateral (
        select count(*)::bigint clicks,count(distinct user_id)::bigint clickers
        from private.area_economy_events e
        where e.event_name='package_checkout_click' and e.object_key=k.package_key and e.created_at>=now()-interval '30 days'
      ) c on true
    ),'[]'::jsonb),
    'gift_transactions_30d',(select count(*)::bigint from private.ac_ledger where transaction_type='gift' and created_at>=now()-interval '30 days'),
    'gift_volume_30d_ac',(select coalesce(sum(amount_ac),0)::bigint from private.ac_ledger where transaction_type='gift' and created_at>=now()-interval '30 days'),
    'gift_senders_30d',(select count(distinct from_user_id)::bigint from private.ac_ledger where transaction_type='gift' and created_at>=now()-interval '30 days' and from_user_id is not null),
    'gift_recipients_30d',(select count(distinct to_user_id)::bigint from private.ac_ledger where transaction_type='gift' and created_at>=now()-interval '30 days' and to_user_id is not null),
    'market_purchases_30d',(select count(*)::bigint from private.ac_ledger where transaction_type='purchase' and created_at>=now()-interval '30 days'),
    'market_volume_30d_ac',(select coalesce(sum(amount_ac),0)::bigint from private.ac_ledger where transaction_type='purchase' and created_at>=now()-interval '30 days'),
    'market_buyers_30d',(select count(distinct from_user_id)::bigint from private.ac_ledger where transaction_type='purchase' and created_at>=now()-interval '30 days' and from_user_id is not null),
    'escalation_fees_30d_ac',(select coalesce(sum(amount_ac),0)::bigint from private.ac_ledger where transaction_type='fee' and note like 'Gbas Gbos escalation%' and created_at>=now()-interval '30 days')
  ) into v_result;
  return v_result;
end;
$function$;
revoke all on function public.get_area_economy_analytics() from public,anon;
grant execute on function public.get_area_economy_analytics() to authenticated;
