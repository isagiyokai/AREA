create or replace function public.get_my_ac_wallet()
returns jsonb language plpgsql security definer set search_path=''
as $function$
declare v_user_id uuid:=auth.uid();v_balance bigint;v_history jsonb;
begin
 if v_user_id is null then raise exception 'Sign in to view your wallet.';end if;
 insert into private.wallet_accounts(user_id,balance_ac) values(v_user_id,0) on conflict(user_id) do nothing;
 select balance_ac into v_balance from private.wallet_accounts where user_id=v_user_id;
 select coalesce(jsonb_agg(jsonb_build_object('id',l.id,'amount_ac',l.amount_ac,'transaction_type',l.transaction_type,'note',l.note,'created_at',l.created_at,'direction',case when l.to_user_id=v_user_id then 'in' else 'out' end,'counterparty',case when l.to_user_id=v_user_id then coalesce(fp.username,'AREA') else coalesce(tp.username,'AREA') end) order by l.created_at desc),'[]'::jsonb)
 into v_history from (select * from private.ac_ledger where from_user_id=v_user_id or to_user_id=v_user_id order by created_at desc limit 40) l
 left join public.profiles fp on fp.id=l.from_user_id left join public.profiles tp on tp.id=l.to_user_id;
 return jsonb_build_object('balance_ac',coalesce(v_balance,0),'history',v_history);
end;$function$;
revoke all on function public.get_my_ac_wallet() from public,anon;
grant execute on function public.get_my_ac_wallet() to authenticated;