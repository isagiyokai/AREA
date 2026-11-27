create table if not exists private.ac_ledger (
 id uuid primary key default gen_random_uuid(),
 from_user_id uuid references auth.users(id) on delete set null,
 to_user_id uuid references auth.users(id) on delete set null,
 amount_ac bigint not null check(amount_ac>0),
 transaction_type text not null check(transaction_type in ('gift','purchase','reward','penance','fee','admin_adjustment','refund')),
 note text, reference_id uuid, created_at timestamptz not null default now(),
 constraint ac_ledger_has_party check(from_user_id is not null or to_user_id is not null),
 constraint ac_ledger_not_self check(from_user_id is null or to_user_id is null or from_user_id<>to_user_id)
);
create index if not exists ac_ledger_from_created_idx on private.ac_ledger(from_user_id,created_at desc);
create index if not exists ac_ledger_to_created_idx on private.ac_ledger(to_user_id,created_at desc);
create unique index if not exists ac_ledger_reference_type_unique on private.ac_ledger(reference_id,transaction_type) where reference_id is not null;
revoke all on private.ac_ledger from public,anon,authenticated;
create or replace function public.get_my_ac_wallet() returns jsonb language plpgsql security definer set search_path='' as $function$
declare v_user_id uuid:=auth.uid(); v_balance bigint; v_history jsonb;
begin
 if v_user_id is null then raise exception 'Sign in to view your wallet.'; end if;
 insert into private.wallet_accounts(user_id,balance_ac) values(v_user_id,0) on conflict(user_id) do nothing;
 select balance_ac into v_balance from private.wallet_accounts where user_id=v_user_id;
 select coalesce(jsonb_agg(jsonb_build_object('id',l.id,'amount_ac',l.amount_ac,'transaction_type',l.transaction_type,'note',l.note,'created_at',l.created_at,'direction',case when l.to_user_id=v_user_id then 'in' else 'out' end,'counterparty',coalesce(fp.username,tp.username,'AREA')) order by l.created_at desc),'[]'::jsonb)
 into v_history from (select * from private.ac_ledger where from_user_id=v_user_id or to_user_id=v_user_id order by created_at desc limit 40) l
 left join public.profiles fp on fp.id=l.from_user_id left join public.profiles tp on tp.id=l.to_user_id;
 return jsonb_build_object('balance_ac',coalesce(v_balance,0),'history',v_history);
end; $function$;
revoke all on function public.get_my_ac_wallet() from public,anon;
grant execute on function public.get_my_ac_wallet() to authenticated;
create or replace function public.transfer_ac(p_recipient_username text,p_amount bigint,p_note text default null)
returns jsonb language plpgsql security definer set search_path='' as $function$
declare v_sender uuid:=auth.uid(); v_recipient uuid; v_sender_balance bigint; v_ledger_id uuid; v_note text:=nullif(left(btrim(coalesce(p_note,'')),120),'');
begin
 if v_sender is null then raise exception 'Sign in before sending AC.'; end if;
 if p_amount is null or p_amount<1 or p_amount>1000000000 then raise exception 'Enter an AC amount between 1 and 1,000,000,000.'; end if;
 if p_recipient_username is null or length(btrim(p_recipient_username)) not between 3 and 24 then raise exception 'Enter a valid citizen username.'; end if;
 select id into v_recipient from public.profiles where username=lower(btrim(p_recipient_username));
 if v_recipient is null then raise exception 'That citizen could not be found.'; end if;
 if v_recipient=v_sender then raise exception 'You cannot send AC to yourself.'; end if;
 insert into private.wallet_accounts(user_id,balance_ac) values(v_sender,0),(v_recipient,0) on conflict(user_id) do nothing;
 perform 1 from private.wallet_accounts where user_id in(v_sender,v_recipient) order by user_id for update;
 select balance_ac into v_sender_balance from private.wallet_accounts where user_id=v_sender;
 if v_sender_balance<p_amount then raise exception 'Not enough AC. Your wallet has % AC.',v_sender_balance; end if;
 update private.wallet_accounts set balance_ac=balance_ac-p_amount,updated_at=now() where user_id=v_sender;
 update private.wallet_accounts set balance_ac=balance_ac+p_amount,updated_at=now() where user_id=v_recipient;
 insert into private.ac_ledger(from_user_id,to_user_id,amount_ac,transaction_type,note) values(v_sender,v_recipient,p_amount,'gift',v_note) returning id into v_ledger_id;
 return jsonb_build_object('transaction_id',v_ledger_id,'amount_ac',p_amount,'balance_ac',v_sender_balance-p_amount,'recipient_username',lower(btrim(p_recipient_username)));
end; $function$;
revoke all on function public.transfer_ac(text,bigint,text) from public,anon;
grant execute on function public.transfer_ac(text,bigint,text) to authenticated;