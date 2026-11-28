-- A signed failure event must not block later authoritative Paystack verification of a successful charge.
create or replace function private.credit_ac_from_verified_payment(p_reference text,p_provider_transaction_id text,p_amount_kobo bigint,p_currency text,p_paid_at timestamptz,p_provider_payload jsonb default '{}'::jsonb)
returns jsonb language plpgsql security invoker set search_path=''
as $function$
declare v_order private.area_payment_orders;v_balance bigint;v_profile public.profiles;v_tier public.area_entry_tiers;
begin
 if current_user<>'service_role' then raise exception 'Payment settlement service access required.';end if;
 select * into v_order from private.area_payment_orders where provider_reference=p_reference and provider='paystack' for update;
 if v_order.id is null then raise exception 'No AREA payment order matches this reference.';end if;
 if v_order.status='paid' then return jsonb_build_object('credited',false,'already_paid',true,'total_ac',v_order.total_ac);end if;
 if v_order.status not in('pending','failed') then raise exception 'This payment order cannot be settled.';end if;
 if upper(coalesce(p_currency,''))<>'NGN' or p_amount_kobo<>v_order.amount_ngn*100 then raise exception 'Verified payment amount or currency does not match the AREA order.';end if;
 if v_order.order_type='entry' then
  select * into v_profile from public.profiles where id=v_order.user_id for update;
  if v_profile.id is null then raise exception 'Citizen profile not found for paid entry.';end if;
  if v_profile.area_entry_tier is not null and (v_profile.area_entry_tier<>'slums_street_material' or v_profile.updated_at<v_order.created_at) then raise exception 'This citizen already has a starting position that predates this payment order.';end if;
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
