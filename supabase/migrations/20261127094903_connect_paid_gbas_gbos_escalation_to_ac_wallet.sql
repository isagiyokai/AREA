create table if not exists public.area_economy_settings(setting_key text primary key,setting_value bigint not null check(setting_value>=0),updated_at timestamptz not null default now());
alter table public.area_economy_settings enable row level security;
drop policy if exists "Public can read economy settings" on public.area_economy_settings;
create policy "Public can read economy settings" on public.area_economy_settings for select to anon,authenticated using(true);
grant select on public.area_economy_settings to anon,authenticated;
insert into public.area_economy_settings(setting_key,setting_value) values
('gbas_gbos_level_2_cost_ac',0),('gbas_gbos_level_3_cost_ac',0),('ac_per_ngn',0),('agbero_default_stamp_duty_ac',0),('agbero_area_share_percent',30),('community_penance_area_share_percent',30)
on conflict(setting_key) do nothing;
create or replace function public.admin_update_area_economy_setting(p_key text,p_value bigint)
returns void language plpgsql security definer set search_path=''
as $function$
begin
 if not public.is_area_admin() then raise exception 'Owner access required.';end if;
 if p_key not in('gbas_gbos_level_2_cost_ac','gbas_gbos_level_3_cost_ac','ac_per_ngn','agbero_default_stamp_duty_ac','agbero_area_share_percent','community_penance_area_share_percent') then raise exception 'Unknown economy setting.';end if;
 if p_value is null or p_value<0 or p_value>1000000000000 then raise exception 'Enter a valid non-negative value.';end if;
 if p_key in('agbero_area_share_percent','community_penance_area_share_percent') and p_value>100 then raise exception 'Share percentages must be between 0 and 100.';end if;
 if p_key='ac_per_ngn' and p_value>1000000 then raise exception 'AC per naira is outside the supported range.';end if;
 insert into public.area_economy_settings(setting_key,setting_value,updated_at) values(p_key,p_value,now())
 on conflict(setting_key) do update set setting_value=excluded.setting_value,updated_at=now();
end;$function$;
revoke all on function public.admin_update_area_economy_setting(text,bigint) from public,anon;
grant execute on function public.admin_update_area_economy_setting(text,bigint) to authenticated;
create or replace function public.request_argument_escalation(p_challenge_id uuid,p_requested_intensity smallint)
returns public.argument_escalation_requests language plpgsql security definer set search_path=''
as $function$
declare v_user_id uuid:=auth.uid();v_challenge public.argument_challenges;v_result public.argument_escalation_requests;v_recent_count integer;v_cost bigint:=0;v_balance bigint:=0;
begin
 if v_user_id is null then raise exception 'Sign in to raise the heat.';end if;
 if exists(select 1 from public.citizen_penances cp where cp.user_id=v_user_id and cp.ends_at>now()) then raise exception 'You are serving a community penance. You can return to the yard when it ends.';end if;
 if p_requested_intensity is null or p_requested_intensity not between 2 and 3 then raise exception 'Choose a valid intensity level.';end if;
 select * into v_challenge from public.argument_challenges where id=p_challenge_id and status='active' and v_user_id in(challenger_id,challenged_id) for update;
 if v_challenge.id is null then raise exception 'This public callout is no longer active.';end if;
 if p_requested_intensity<=v_challenge.intensity then raise exception 'Choose an intensity higher than the current level.';end if;
 select setting_value into v_cost from public.area_economy_settings where setting_key=case when p_requested_intensity=2 then 'gbas_gbos_level_2_cost_ac' else 'gbas_gbos_level_3_cost_ac' end;
 v_cost:=coalesce(v_cost,0);
 select count(*) into v_recent_count from public.argument_escalation_requests where requester_id=v_user_id and created_at>now()-interval '24 hours';
 if v_recent_count>=10 then raise exception 'You have reached today’s escalation limit. Try again later.';end if;
 update public.argument_escalation_requests set status='cancelled',responded_at=now(),responded_by=v_user_id where challenge_id=p_challenge_id and status='pending';
 if v_cost>0 then
  insert into private.wallet_accounts(user_id,balance_ac) values(v_user_id,0) on conflict(user_id) do nothing;
  perform 1 from private.wallet_accounts where user_id=v_user_id for update;
  select balance_ac into v_balance from private.wallet_accounts where user_id=v_user_id;
  if v_balance<v_cost then raise exception 'Raising the heat costs % AC. Your wallet has % AC.',v_cost,v_balance;end if;
  update private.wallet_accounts set balance_ac=balance_ac-v_cost,updated_at=now() where user_id=v_user_id;
  insert into private.ac_ledger(from_user_id,amount_ac,transaction_type,note) values(v_user_id,v_cost,'fee','Gbas Gbos escalation to intensity '||p_requested_intensity::text);
 end if;
 update public.argument_challenges set intensity=p_requested_intensity where id=p_challenge_id returning * into v_challenge;
 insert into public.argument_escalation_requests(challenge_id,requester_id,requested_intensity,status,responded_at,responded_by)
 values(p_challenge_id,v_user_id,p_requested_intensity,'accepted',now(),v_user_id) returning * into v_result;
 return v_result;
end;$function$;
revoke all on function public.request_argument_escalation(uuid,smallint) from public,anon;
grant execute on function public.request_argument_escalation(uuid,smallint) to authenticated;