create or replace function public.create_argument_challenge(p_post_id uuid,p_opponent_id uuid,p_intensity smallint)
returns public.argument_challenges language plpgsql security definer set search_path=''
as $function$
declare v_user_id uuid:=auth.uid();v_result public.argument_challenges;v_post_author uuid;v_recent_count integer;v_limit integer:=10;v_privileges jsonb;
begin
 if v_user_id is null then raise exception 'You must sign in to make a public callout.';end if;
 if exists(select 1 from public.citizen_penances cp where cp.user_id=v_user_id and cp.ends_at>now()) then raise exception 'You are serving a community penance. You can return to the yard when it ends.';end if;
 if exists(select 1 from public.agbero_territories t where t.active=true) and not exists(select 1 from public.agbero_memberships m where m.citizen_id=v_user_id and m.status='inside') then raise exception 'Enter an Agbero territory before joining the street.';end if;
 if p_intensity is null or p_intensity not between 1 and 3 then raise exception 'Choose a valid intensity level.';end if;
 if p_opponent_id is null or p_opponent_id=v_user_id then raise exception 'Choose another citizen to call out.';end if;
 select t.privileges into v_privileges from public.profiles p left join public.area_entry_tiers t on t.tier_key=p.area_entry_tier where p.id=v_user_id;
 if coalesce(v_privileges->>'daily_callout_limit','') ~ '^[0-9]{1,3}$' then v_limit:=greatest(1,least(100,(v_privileges->>'daily_callout_limit')::integer));end if;
 select p.author_id into v_post_author from public.posts p where p.id=p_post_id;
 if v_post_author is null then raise exception 'This conversation no longer exists.';end if;
 if not exists(select 1 from public.profiles pr where pr.id=p_opponent_id) then raise exception 'That citizen could not be found.';end if;
 if p_opponent_id<>v_post_author and not exists(select 1 from public.replies r where r.post_id=p_post_id and r.author_id=p_opponent_id) then raise exception 'You can only call out a citizen who has joined this conversation.';end if;
 update public.argument_challenges ac set status='expired',ended_at=now() where ac.post_id=p_post_id and ac.status='pending' and ac.expires_at<=now() and((ac.challenger_id=v_user_id and ac.challenged_id=p_opponent_id)or(ac.challenger_id=p_opponent_id and ac.challenged_id=v_user_id));
 select count(*) into v_recent_count from public.argument_challenges ac where ac.challenger_id=v_user_id and ac.created_at>now()-interval '24 hours';
 if v_recent_count>=v_limit then raise exception 'You have reached today’s callout limit (%). Try again later.',v_limit;end if;
 insert into public.argument_challenges(post_id,challenger_id,challenged_id,intensity,status,accepted_at) values(p_post_id,v_user_id,p_opponent_id,p_intensity,'active',now()) returning * into v_result;
 return v_result;
exception when unique_violation then raise exception 'There is already an open callout between these citizens in this conversation.';
end;$function$;
revoke all on function public.create_argument_challenge(uuid,uuid,smallint) from public,anon;grant execute on function public.create_argument_challenge(uuid,uuid,smallint) to authenticated;
create or replace function public.request_argument_escalation(p_challenge_id uuid,p_requested_intensity smallint)
returns public.argument_escalation_requests language plpgsql security definer set search_path=''
as $function$
declare v_user_id uuid:=auth.uid();v_challenge public.argument_challenges;v_result public.argument_escalation_requests;v_recent_count integer;v_cost bigint:=0;v_balance bigint:=0;v_limit integer:=10;v_privileges jsonb;
begin
 if v_user_id is null then raise exception 'Sign in to raise the heat.';end if;
 if exists(select 1 from public.citizen_penances cp where cp.user_id=v_user_id and cp.ends_at>now()) then raise exception 'You are serving a community penance. You can return to the yard when it ends.';end if;
 if p_requested_intensity is null or p_requested_intensity not between 2 and 3 then raise exception 'Choose a valid intensity level.';end if;
 select * into v_challenge from public.argument_challenges where id=p_challenge_id and status='active' and v_user_id in(challenger_id,challenged_id) for update;
 if v_challenge.id is null then raise exception 'This public callout is no longer active.';end if;
 if p_requested_intensity<=v_challenge.intensity then raise exception 'Choose an intensity higher than the current level.';end if;
 select t.privileges into v_privileges from public.profiles p left join public.area_entry_tiers t on t.tier_key=p.area_entry_tier where p.id=v_user_id;
 if coalesce(v_privileges->>'daily_escalation_limit','') ~ '^[0-9]{1,3}$' then v_limit:=greatest(1,least(100,(v_privileges->>'daily_escalation_limit')::integer));end if;
 select setting_value into v_cost from public.area_economy_settings where setting_key=case when p_requested_intensity=2 then 'gbas_gbos_level_2_cost_ac' else 'gbas_gbos_level_3_cost_ac' end;v_cost:=coalesce(v_cost,0);
 select count(*) into v_recent_count from public.argument_escalation_requests where requester_id=v_user_id and created_at>now()-interval '24 hours';
 if v_recent_count>=v_limit then raise exception 'You have reached today’s escalation limit (%). Try again later.',v_limit;end if;
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
 insert into public.argument_escalation_requests(challenge_id,requester_id,requested_intensity,status,responded_at,responded_by) values(p_challenge_id,v_user_id,p_requested_intensity,'accepted',now(),v_user_id) returning * into v_result;
 return v_result;
end;$function$;
revoke all on function public.request_argument_escalation(uuid,smallint) from public,anon;grant execute on function public.request_argument_escalation(uuid,smallint) to authenticated;