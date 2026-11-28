-- AREA paid entry checkout and entry revenue accounting.
alter table private.area_payment_orders alter column package_key drop not null;
alter table private.area_payment_orders add column if not exists order_type text not null default 'topup';
alter table private.area_payment_orders add column if not exists tier_key text references public.area_entry_tiers(tier_key);
alter table private.area_payment_orders drop constraint if exists area_payment_orders_order_type_check;
alter table private.area_payment_orders add constraint area_payment_orders_order_type_check check((order_type='topup' and package_key is not null and tier_key is null) or (order_type='entry' and package_key is null and tier_key is not null));
create index if not exists area_payment_orders_tier_key_idx on private.area_payment_orders(tier_key);
create index if not exists area_payment_orders_package_key_idx on private.area_payment_orders(package_key);

create or replace function public.create_ac_topup_order(p_package_key text) returns jsonb language plpgsql security definer set search_path=''
as $function$
declare v_user uuid:=auth.uid();v_package public.area_ac_packages;v_reference text;v_order private.area_payment_orders;
begin
 if v_user is null then raise exception 'Sign in before buying AC.';end if;
 select * into v_package from public.area_ac_packages where package_key=p_package_key and active=true;
 if v_package.package_key is null then raise exception 'This AC package is not available.';end if;
 if (select count(*) from private.area_payment_orders where user_id=v_user and status='pending' and created_at>now()-interval '1 hour')>=5 then raise exception 'You have too many unfinished payment attempts. Wait a little and try again.';end if;
 v_reference:='area_'||replace(gen_random_uuid()::text,'-','');
 insert into private.area_payment_orders(user_id,order_type,package_key,amount_ngn,base_ac,bonus_ac,provider_reference) values(v_user,'topup',v_package.package_key,v_package.amount_ngn,v_package.base_ac,v_package.bonus_ac,v_reference) returning * into v_order;
 return jsonb_build_object('order_id',v_order.id,'reference',v_order.provider_reference,'amount_ngn',v_order.amount_ngn,'base_ac',v_order.base_ac,'bonus_ac',v_order.bonus_ac,'total_ac',v_order.total_ac,'currency','NGN','order_type','topup');
end;$function$;
revoke all on function public.create_ac_topup_order(text) from public,anon;
grant execute on function public.create_ac_topup_order(text) to authenticated;

create or replace function public.create_area_entry_order(p_tier_key text) returns jsonb language plpgsql security definer set search_path=''
as $function$
declare v_user uuid:=auth.uid();v_current_tier text;v_tier public.area_entry_tiers;v_reference text;v_order private.area_payment_orders;
begin
 if v_user is null then raise exception 'Sign in before choosing a paid entry.';end if;
 select area_entry_tier into v_current_tier from public.profiles where id=v_user for update;
 if not found then raise exception 'Citizen profile not found.';end if;
 if v_current_tier is not null and v_current_tier<>'slums_street_material' then raise exception 'Your starting position has already been selected.';end if;
 update private.area_payment_orders set status='failed' where user_id=v_user and order_type='entry' and status='pending' and expires_at<=now();
 if exists(select 1 from private.area_payment_orders where user_id=v_user and order_type='entry' and status='pending' and expires_at>now()) then raise exception 'You already have a paid entry checkout in progress. Finish it or wait for it to expire.';end if;
 select * into v_tier from public.area_entry_tiers where tier_key=p_tier_key and active=true and price_ngn>0;
 if v_tier.tier_key is null then raise exception 'This paid entry tier is not available.';end if;
 v_reference:='area_'||replace(gen_random_uuid()::text,'-','');
 insert into private.area_payment_orders(user_id,order_type,tier_key,amount_ngn,base_ac,bonus_ac,provider_reference) values(v_user,'entry',v_tier.tier_key,v_tier.price_ngn,v_tier.starting_ac,0,v_reference) returning * into v_order;
 return jsonb_build_object('order_id',v_order.id,'reference',v_order.provider_reference,'amount_ngn',v_order.amount_ngn,'base_ac',v_order.base_ac,'bonus_ac',0,'total_ac',v_order.total_ac,'currency','NGN','order_type','entry','tier_key',v_tier.tier_key);
end;$function$;
revoke all on function public.create_area_entry_order(text) from public,anon;
grant execute on function public.create_area_entry_order(text) to authenticated;

create or replace function public.select_free_slums_entry() returns jsonb language plpgsql security definer set search_path=''
as $function$
declare v_user uuid:=auth.uid();v_grade text;v_selected text;
begin
 if v_user is null then raise exception 'Sign in to choose your AREA entry.';end if;
 select area_entry_tier into v_selected from public.profiles where id=v_user for update;
 if not found then raise exception 'Citizen profile not found.';end if;
 if v_selected is not null then raise exception 'Your entry tier has already been selected.';end if;
 update private.area_payment_orders set status='failed' where user_id=v_user and order_type='entry' and status='pending' and expires_at<=now();
 if exists(select 1 from private.area_payment_orders where user_id=v_user and order_type='entry' and status='pending' and expires_at>now()) then raise exception 'A paid entry checkout is in progress. Finish it or wait for it to expire before choosing Slums.';end if;
 select grade_title into v_grade from public.area_entry_tiers where tier_key='slums_street_material';
 update public.profiles set area_class='slums',area_grade=v_grade,area_entry_tier='slums_street_material',updated_at=now() where id=v_user;
 return jsonb_build_object('area_class','slums','area_grade',v_grade,'entry_tier','slums_street_material','price_ngn',0,'starting_ac',0);
end;$function$;
revoke all on function public.select_free_slums_entry() from public,anon;
grant execute on function public.select_free_slums_entry() to authenticated;

create or replace function private.credit_ac_from_verified_payment(p_reference text,p_provider_transaction_id text,p_amount_kobo bigint,p_currency text,p_paid_at timestamptz,p_provider_payload jsonb default '{}'::jsonb)
returns jsonb language plpgsql security invoker set search_path=''
as $function$
declare v_order private.area_payment_orders;v_balance bigint;v_profile public.profiles;v_tier public.area_entry_tiers;
begin
 if current_user<>'service_role' then raise exception 'Payment settlement service access required.';end if;
 select * into v_order from private.area_payment_orders where provider_reference=p_reference and provider='paystack' for update;
 if v_order.id is null then raise exception 'No AREA payment order matches this reference.';end if;
 if v_order.status='paid' then return jsonb_build_object('credited',false,'already_paid',true,'total_ac',v_order.total_ac);end if;
 if v_order.status not in('pending','failed') or (v_order.status='failed' and v_order.order_type<>'entry') then raise exception 'This payment order cannot be settled.';end if;
 if upper(coalesce(p_currency,''))<>'NGN' or p_amount_kobo<>v_order.amount_ngn*100 then raise exception 'Verified payment amount or currency does not match the AREA order.';end if;
 if v_order.order_type='entry' then
  select * into v_profile from public.profiles where id=v_order.user_id for update;
  if v_profile.id is null then raise exception 'Citizen profile not found for paid entry.';end if;
  if v_profile.area_entry_tier is not null and v_profile.area_entry_tier<>'slums_street_material' then raise exception 'This citizen already has a paid starting position.';end if;
  select * into v_tier from public.area_entry_tiers where tier_key=v_order.tier_key and active=true;
  if v_tier.tier_key is null then raise exception 'This entry tier is no longer available.';end if;
  update public.profiles set area_class=v_tier.area_class,area_grade=v_tier.grade_title,area_entry_tier=v_tier.tier_key,updated_at=now() where id=v_order.user_id;
  if v_order.base_ac>0 then
   insert into private.wallet_accounts(user_id,balance_ac) values(v_order.user_id,0) on conflict(user_id) do nothing;
   perform 1 from private.wallet_accounts where user_id=v_order.user_id for update;
   update private.wallet_accounts set balance_ac=balance_ac+v_order.base_ac,updated_at=now() where user_id=v_order.user_id;
   insert into private.ac_ledger(to_user_id,amount_ac,transaction_type,note,reference_id) values(v_order.user_id,v_order.base_ac,'bonus','Paid entry starting balance · '||v_order.tier_key,v_order.id);
  end if;
 else
  insert into private.wallet_accounts(user_id,balance_ac) values(v_order.user_id,0) on conflict(user_id) do nothing;
  perform 1 from private.wallet_accounts where user_id=v_order.user_id for update;
  update private.wallet_accounts set balance_ac=balance_ac+v_order.total_ac,updated_at=now() where user_id=v_order.user_id;
  insert into private.ac_ledger(to_user_id,amount_ac,transaction_type,note,reference_id) values(v_order.user_id,v_order.base_ac,'topup','Paystack AC purchase · '||v_order.package_key,v_order.id);
  if v_order.bonus_ac>0 then insert into private.ac_ledger(to_user_id,amount_ac,transaction_type,note,reference_id) values(v_order.user_id,v_order.bonus_ac,'bonus','AC package bonus · '||v_order.package_key,v_order.id);end if;
 end if;
 update private.area_payment_orders set status='paid',provider_transaction_id=p_provider_transaction_id,provider_payload=coalesce(p_provider_payload,'{}'::jsonb),paid_at=coalesce(p_paid_at,now()) where id=v_order.id;
 return jsonb_build_object('credited',true,'already_paid',false,'order_type',v_order.order_type,'base_ac',v_order.base_ac,'bonus_ac',v_order.bonus_ac,'total_ac',v_order.total_ac);
end;$function$;
revoke all on function private.credit_ac_from_verified_payment(text,text,bigint,text,timestamptz,jsonb) from public,anon,authenticated;
grant execute on function private.credit_ac_from_verified_payment(text,text,bigint,text,timestamptz,jsonb) to service_role;

create or replace function public.get_area_treasury_overview() returns jsonb language plpgsql security definer set search_path=''
as $function$
declare v_result jsonb;
begin
 if not public.is_area_admin() then raise exception 'Owner access required.';end if;
 select jsonb_build_object(
  'wallet_count',(select count(*)::bigint from private.wallet_accounts),'outstanding_ac',(select coalesce(sum(balance_ac),0)::bigint from private.wallet_accounts),
  'gift_volume_ac',(select coalesce(sum(amount_ac),0)::bigint from private.ac_ledger where transaction_type='gift'),
  'reward_volume_ac',(select coalesce(sum(amount_ac),0)::bigint from private.ac_ledger where transaction_type in('reward','bonus')),
  'community_jury_paid_ac',(select coalesce(sum(amount_ac),0)::bigint from private.ac_ledger where transaction_type='reward' and note like 'Community jury share%'),
  'topup_ac',(select coalesce(sum(amount_ac),0)::bigint from private.ac_ledger where transaction_type='topup'),
  'topup_bonus_ac',(select coalesce(sum(amount_ac),0)::bigint from private.ac_ledger where transaction_type='bonus' and note like 'AC package bonus%'),
  'topup_revenue_ngn',(select coalesce(sum(amount_ngn),0)::bigint from private.area_payment_orders where status='paid' and order_type='topup'),
  'entry_revenue_ngn',(select coalesce(sum(amount_ngn),0)::bigint from private.area_payment_orders where status='paid' and order_type='entry'),
  'successful_topups',(select count(*)::bigint from private.area_payment_orders where status='paid' and order_type='topup'),
  'successful_entry_purchases',(select count(*)::bigint from private.area_payment_orders where status='paid' and order_type='entry'),
  'pending_topups',(select count(*)::bigint from private.area_payment_orders where status='pending' and order_type='topup'),
  'pending_entry_purchases',(select count(*)::bigint from private.area_payment_orders where status='pending' and order_type='entry'),
  'entry_starting_ac',(select coalesce(sum(amount_ac),0)::bigint from private.ac_ledger where transaction_type='bonus' and note like 'Paid entry starting balance%'),
  'penance_collected_ac',(select coalesce(sum(amount_ac),0)::bigint from private.ac_ledger where transaction_type='penance'),
  'fees_collected_ac',(select coalesce(sum(amount_ac),0)::bigint from private.ac_ledger where transaction_type='fee'),
  'agbero_area_share_ac',(select coalesce(sum(amount_ac),0)::bigint from private.ac_ledger where transaction_type='fee' and to_user_id is null and note like 'AREA share of Agbero stamp duty:%'),
  'escalation_fee_ac',(select coalesce(sum(amount_ac),0)::bigint from private.ac_ledger where transaction_type='fee' and to_user_id is null and note like 'Gbas Gbos escalation%'),
  'market_purchase_volume_ac',(select coalesce(sum(amount_ac),0)::bigint from private.ac_ledger where transaction_type='purchase'),
  'area_retained_ac',(select coalesce(sum(amount_ac),0)::bigint from private.ac_ledger where transaction_type='fee' and to_user_id is null)+(select coalesce(sum(amount_ac),0)::bigint from private.ac_ledger where transaction_type='purchase')+(select coalesce(sum(amount_ac),0)::bigint from private.ac_ledger where transaction_type='penance')-(select coalesce(sum(amount_ac),0)::bigint from private.ac_ledger where transaction_type='reward' and note like 'Community jury share%'),
  'refunds_ac',(select coalesce(sum(amount_ac),0)::bigint from private.ac_ledger where transaction_type='refund')
 ) into v_result;return v_result;
end;$function$;
revoke all on function public.get_area_treasury_overview() from public,anon;
grant execute on function public.get_area_treasury_overview() to authenticated;

revoke execute on function public.is_area_admin_profile(uuid) from anon;
grant execute on function public.is_area_admin_profile(uuid) to authenticated;
