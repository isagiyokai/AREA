-- AREA Financial Engine v1
-- Internal AC package catalogue and verified Paystack settlement.
alter table private.ac_ledger drop constraint if exists ac_ledger_transaction_type_check;
alter table private.ac_ledger add constraint ac_ledger_transaction_type_check
 check (transaction_type in ('gift','purchase','reward','penance','fee','admin_adjustment','refund','topup','bonus'));
create table if not exists public.area_ac_packages (
 package_key text primary key,name text not null,amount_ngn bigint not null check(amount_ngn>=100),
 base_ac bigint not null check(base_ac>0),bonus_ac bigint not null default 0 check(bonus_ac>=0),
 active boolean not null default true,sort_order smallint not null default 0,created_at timestamptz not null default now()
);
alter table public.area_ac_packages enable row level security;
drop policy if exists "Citizens can read active AC packages" on public.area_ac_packages;
create policy "Citizens can read active AC packages" on public.area_ac_packages for select to authenticated using(active=true);
grant select on public.area_ac_packages to authenticated;
insert into public.area_ac_packages(package_key,name,amount_ngn,base_ac,bonus_ac,sort_order) values
 ('pocket','Pocket',100,5000,0,1),('small','Small',200,10000,0,2),
 ('street','Street',500,25000,500,3),('regular','Regular',1000,50000,2500,4),
 ('big_man','Big Man',2500,125000,12500,5),('odogwu','Odogwu',5000,250000,37500,6)
on conflict(package_key) do update set name=excluded.name,amount_ngn=excluded.amount_ngn,base_ac=excluded.base_ac,bonus_ac=excluded.bonus_ac,sort_order=excluded.sort_order;
create table if not exists private.area_payment_orders (
 id uuid primary key default gen_random_uuid(),user_id uuid not null references auth.users(id) on delete restrict,
 package_key text not null references public.area_ac_packages(package_key),amount_ngn bigint not null check(amount_ngn>0),
 base_ac bigint not null check(base_ac>0),bonus_ac bigint not null default 0 check(bonus_ac>=0),
 total_ac bigint generated always as(base_ac+bonus_ac) stored,
 provider text not null default 'paystack' check(provider='paystack'),provider_reference text not null unique,
 provider_transaction_id text unique,status text not null default 'pending' check(status in('pending','paid','failed','refunded')),
 provider_payload jsonb not null default '{}'::jsonb,created_at timestamptz not null default now(),
 expires_at timestamptz not null default(now()+interval '30 minutes'),paid_at timestamptz
);
create index if not exists area_payment_orders_user_created_idx on private.area_payment_orders(user_id,created_at desc);
create index if not exists area_payment_orders_status_created_idx on private.area_payment_orders(status,created_at desc);
alter table private.area_payment_orders enable row level security;
revoke all on private.area_payment_orders from public,anon,authenticated;
grant usage on schema private to service_role;
grant select,insert,update on private.wallet_accounts,private.ac_ledger,private.area_payment_orders to service_role;
create or replace function public.create_ac_topup_order(p_package_key text) returns jsonb
language plpgsql security definer set search_path=''
as $function$
declare v_user uuid:=auth.uid();v_package public.area_ac_packages;v_reference text;v_order private.area_payment_orders;
begin
 if v_user is null then raise exception 'Sign in before buying AC.';end if;
 select * into v_package from public.area_ac_packages where package_key=p_package_key and active=true;
 if v_package.package_key is null then raise exception 'This AC package is not available.';end if;
 if (select count(*) from private.area_payment_orders where user_id=v_user and status='pending' and created_at>now()-interval '1 hour')>=5 then raise exception 'You have too many unfinished payment attempts. Wait a little and try again.';end if;
 v_reference:='area_'||replace(gen_random_uuid()::text,'-','');
 insert into private.area_payment_orders(user_id,package_key,amount_ngn,base_ac,bonus_ac,provider_reference)
 values(v_user,v_package.package_key,v_package.amount_ngn,v_package.base_ac,v_package.bonus_ac,v_reference) returning * into v_order;
 return jsonb_build_object('order_id',v_order.id,'reference',v_order.provider_reference,'amount_ngn',v_order.amount_ngn,'base_ac',v_order.base_ac,'bonus_ac',v_order.bonus_ac,'total_ac',v_order.total_ac,'currency','NGN');
end;$function$;
revoke all on function public.create_ac_topup_order(text) from public,anon;
grant execute on function public.create_ac_topup_order(text) to authenticated;
create or replace function private.credit_ac_from_verified_payment(
 p_reference text,p_provider_transaction_id text,p_amount_kobo bigint,p_currency text,p_paid_at timestamptz,p_provider_payload jsonb default '{}'::jsonb
) returns jsonb language plpgsql security invoker set search_path=''
as $function$
declare v_order private.area_payment_orders;v_balance bigint;
begin
 if current_user<>'service_role' then raise exception 'Payment settlement service access required.';end if;
 select * into v_order from private.area_payment_orders where provider_reference=p_reference and provider='paystack' for update;
 if v_order.id is null then raise exception 'No AREA payment order matches this reference.';end if;
 if v_order.status='paid' then return jsonb_build_object('credited',false,'already_paid',true,'total_ac',v_order.total_ac);end if;
 if v_order.status<>'pending' then raise exception 'This payment order cannot be settled.';end if;
 if upper(coalesce(p_currency,''))<>'NGN' or p_amount_kobo<>v_order.amount_ngn*100 then raise exception 'Verified payment amount or currency does not match the AREA order.';end if;
 insert into private.wallet_accounts(user_id,balance_ac) values(v_order.user_id,0) on conflict(user_id) do nothing;
 perform 1 from private.wallet_accounts where user_id=v_order.user_id for update;
 select balance_ac into v_balance from private.wallet_accounts where user_id=v_order.user_id;
 update private.wallet_accounts set balance_ac=balance_ac+v_order.total_ac,updated_at=now() where user_id=v_order.user_id;
 insert into private.ac_ledger(to_user_id,amount_ac,transaction_type,note,reference_id) values(v_order.user_id,v_order.base_ac,'topup','Paystack AC purchase · '||v_order.package_key,v_order.id);
 if v_order.bonus_ac>0 then insert into private.ac_ledger(to_user_id,amount_ac,transaction_type,note,reference_id) values(v_order.user_id,v_order.bonus_ac,'bonus','AC package bonus · '||v_order.package_key,v_order.id);end if;
 update private.area_payment_orders set status='paid',provider_transaction_id=p_provider_transaction_id,provider_payload=coalesce(p_provider_payload,'{}'::jsonb),paid_at=coalesce(p_paid_at,now()) where id=v_order.id;
 return jsonb_build_object('credited',true,'already_paid',false,'base_ac',v_order.base_ac,'bonus_ac',v_order.bonus_ac,'total_ac',v_order.total_ac,'balance_ac',v_balance+v_order.total_ac);
end;$function$;
revoke all on function private.credit_ac_from_verified_payment(text,text,bigint,text,timestamptz,jsonb) from public,anon,authenticated;
grant execute on function private.credit_ac_from_verified_payment(text,text,bigint,text,timestamptz,jsonb) to service_role;
create or replace function public.settle_verified_ac_payment(p_reference text,p_provider_transaction_id text,p_amount_kobo bigint,p_currency text,p_paid_at timestamptz,p_provider_payload jsonb default '{}'::jsonb)
returns jsonb language sql security invoker set search_path=''
as $function$ select private.credit_ac_from_verified_payment(p_reference,p_provider_transaction_id,p_amount_kobo,p_currency,p_paid_at,p_provider_payload); $function$;
revoke all on function public.settle_verified_ac_payment(text,text,bigint,text,timestamptz,jsonb) from public,anon,authenticated;
grant execute on function public.settle_verified_ac_payment(text,text,bigint,text,timestamptz,jsonb) to service_role;
update public.area_market_items set price_ac=case slug when 'street-frame' then 5000 when 'yard-mark' then 7500 when 'ink-nameplate' then 10000 when 'after-hours' then 15000 else price_ac end where slug in('street-frame','yard-mark','ink-nameplate','after-hours');
update public.area_economy_settings set setting_value=case setting_key when 'gbas_gbos_level_2_cost_ac' then 500 when 'gbas_gbos_level_3_cost_ac' then 1500 else setting_value end,updated_at=now() where setting_key in('gbas_gbos_level_2_cost_ac','gbas_gbos_level_3_cost_ac');
update public.area_entry_tiers set starting_ac=case tier_key when 'lapo_starter' then 5000 when 'lapo_senior_man' then 10000 when 'nepo_odogwu' then 25000 else 0 end,
 privileges=case tier_key when 'slums_street_material' then '{"daily_callout_limit":10,"daily_escalation_limit":2}'::jsonb when 'lapo_starter' then '{"daily_callout_limit":10,"daily_escalation_limit":4}'::jsonb when 'lapo_senior_man' then '{"daily_callout_limit":10,"daily_escalation_limit":6}'::jsonb when 'nepo_odogwu' then '{"daily_callout_limit":10,"daily_escalation_limit":8}'::jsonb else privileges end
where tier_key in('slums_street_material','lapo_starter','lapo_senior_man','nepo_odogwu');
