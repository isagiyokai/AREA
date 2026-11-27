create or replace function public.request_community_apology(p_case_id uuid,p_apology text)
returns void language plpgsql security definer set search_path=''
as $function$
declare v_case public.community_cases;
begin
 if auth.uid() is null then raise exception 'Sign in first.';end if;
 if length(trim(coalesce(p_apology,'')))<10 or length(p_apology)>1000 then raise exception 'Write an apology between 10 and 1,000 characters.';end if;
 select * into v_case from public.community_cases where id=p_case_id for update;
 if v_case.id is null or v_case.target_user_id<>auth.uid() or v_case.status<>'upheld' then raise exception 'Only the citizen serving this case can submit an apology.';end if;
 if v_case.offended_user_id is null then raise exception 'This case has no directly identified offended citizen to receive an apology.';end if;
 if v_case.penance_until is null or v_case.penance_until<=now() then raise exception 'The penance period has ended; the citizen has already earned their return.';end if;
 if v_case.apology_accepted_at is not null then raise exception 'This apology has already been resolved.';end if;
 update public.community_cases set apology_text=trim(p_apology),apology_submitted_at=now() where id=p_case_id;
end;$function$;
revoke all on function public.request_community_apology(uuid,text) from public,anon;
grant execute on function public.request_community_apology(uuid,text) to authenticated;

create or replace function public.accept_community_apology(p_case_id uuid)
returns jsonb language plpgsql security definer set search_path=''
as $function$
declare v_case public.community_cases;v_fee bigint;v_balance bigint;v_area bigint;v_pool bigint;v_share bigint;v_voters integer;v_vote record;
begin
 if auth.uid() is null then raise exception 'Sign in first.';end if;
 select * into v_case from public.community_cases where id=p_case_id for update;
 if v_case.id is null or v_case.offended_user_id<>auth.uid() or v_case.status<>'upheld' or v_case.apology_submitted_at is null then raise exception 'Only the directly offended citizen can accept this apology.';end if;
 if v_case.penance_until is null or v_case.penance_until<=now() then raise exception 'The penance period has ended; the citizen has already earned their return.';end if;
 if v_case.apology_accepted_at is not null then raise exception 'This apology has already been accepted.';end if;
 select setting_value into v_fee from public.area_economy_settings where setting_key='community_forgiveness_return_fee_ac';v_fee:=coalesce(v_fee,500000);
 insert into private.wallet_accounts(user_id,balance_ac) values(v_case.target_user_id,0) on conflict(user_id) do nothing;
 perform 1 from private.wallet_accounts where user_id=v_case.target_user_id for update;
 select balance_ac into v_balance from private.wallet_accounts where user_id=v_case.target_user_id;
 if v_balance<v_fee then raise exception 'Forgiveness is accepted, but return costs % AC. This citizen currently has % AC.',v_fee,v_balance;end if;
 update private.wallet_accounts set balance_ac=balance_ac-v_fee,updated_at=now() where user_id=v_case.target_user_id;
 insert into private.ac_ledger(from_user_id,amount_ac,transaction_type,note) values(v_case.target_user_id,v_fee,'penance','Forgiveness return fee for Wolves case '||p_case_id::text);
 select setting_value into v_area from public.area_economy_settings where setting_key='community_penance_area_share_percent';v_area:=coalesce(v_area,30);
 v_pool:=v_fee-floor(v_fee*v_area/100.0)::bigint;
 select count(*)::int into v_voters from public.community_case_votes where case_id=p_case_id;
 if v_voters>0 then v_share:=floor(v_pool/v_voters);end if;
 if v_share>0 then for v_vote in select voter_id from public.community_case_votes where case_id=p_case_id loop
  insert into private.wallet_accounts(user_id,balance_ac) values(v_vote.voter_id,0) on conflict(user_id) do nothing;
  update private.wallet_accounts set balance_ac=balance_ac+v_share,updated_at=now() where user_id=v_vote.voter_id;
  insert into private.ac_ledger(to_user_id,amount_ac,transaction_type,note) values(v_vote.voter_id,v_share,'reward','Community jury share for forgiveness case '||p_case_id::text);
 end loop;end if;
 update public.community_cases set apology_accepted_at=now(),reinstated_at=now(),ac_penalty_collected=ac_penalty_collected+v_fee where id=p_case_id;
 update public.citizen_penances set ends_at=now(),served_at=now() where case_id=p_case_id and user_id=v_case.target_user_id and served_at is null;
 return jsonb_build_object('status','reinstated','fee_ac',v_fee,'area_share_ac',floor(v_fee*v_area/100.0)::bigint,'jury_pool_ac',v_pool);
end;$function$;
revoke all on function public.accept_community_apology(uuid) from public,anon;
grant execute on function public.accept_community_apology(uuid) to authenticated;