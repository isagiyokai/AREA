create or replace function public.admin_adjust_ac(p_username text,p_amount bigint,p_direction text,p_note text default null)
returns jsonb language plpgsql security definer set search_path=''
as $function$
declare v_user uuid;v_balance bigint;v_next bigint;v_note text:=nullif(left(btrim(coalesce(p_note,'')),120),'');
begin
 if not public.is_area_admin() then raise exception 'Owner access required.';end if;
 if p_amount is null or p_amount<1 or p_amount>1000000000 then raise exception 'Enter an AC amount between 1 and 1,000,000,000.';end if;
 if p_direction not in('credit','debit') then raise exception 'Choose credit or debit.';end if;
 select id into v_user from public.profiles where username=lower(btrim(p_username));
 if v_user is null then raise exception 'Citizen not found.';end if;
 insert into private.wallet_accounts(user_id,balance_ac) values(v_user,0) on conflict(user_id) do nothing;
 perform 1 from private.wallet_accounts where user_id=v_user for update;
 select balance_ac into v_balance from private.wallet_accounts where user_id=v_user;
 if p_direction='debit' and v_balance<p_amount then raise exception 'Wallet only has % AC.',v_balance;end if;
 v_next:=case when p_direction='credit' then v_balance+p_amount else v_balance-p_amount end;
 update private.wallet_accounts set balance_ac=v_next,updated_at=now() where user_id=v_user;
 if p_direction='credit' then
  insert into private.ac_ledger(to_user_id,amount_ac,transaction_type,note) values(v_user,p_amount,'admin_adjustment',coalesce(v_note,'AREA owner credit'));
 else
  insert into private.ac_ledger(from_user_id,amount_ac,transaction_type,note) values(v_user,p_amount,'admin_adjustment',coalesce(v_note,'AREA owner debit'));
 end if;
 return jsonb_build_object('username',lower(btrim(p_username)),'direction',p_direction,'amount_ac',p_amount,'balance_ac',v_next);
end;$function$;
revoke all on function public.admin_adjust_ac(text,bigint,text,text) from public,anon;
grant execute on function public.admin_adjust_ac(text,bigint,text,text) to authenticated;