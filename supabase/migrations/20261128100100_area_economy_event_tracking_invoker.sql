drop policy if exists "Citizens can record their own economy events" on private.area_economy_events;
create policy "Citizens can record their own economy events"
on private.area_economy_events for insert to authenticated
with check (user_id = (select auth.uid()));
grant usage on schema private to authenticated;
grant insert on private.area_economy_events to authenticated;

create or replace function public.track_area_economy_event(p_event_name text,p_object_key text default null)
returns boolean
language plpgsql
security invoker
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