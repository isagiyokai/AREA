-- Add payer conversion, repeat payer and revenue cohort metrics to owner treasury.
create or replace function public.get_area_treasury_overview()
returns jsonb language plpgsql security definer set search_path=''
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
  'gross_payments_ngn',(select coalesce(sum(amount_ngn),0)::bigint from private.area_payment_orders where status='paid'),
  'provider_fees_ngn',(select coalesce(sum(coalesce(nullif(provider_payload->>'fees_kobo','')::bigint,0)),0)::numeric/100 from private.area_payment_orders where status='paid'),
  'net_after_provider_fees_ngn',(select coalesce(sum(amount_ngn*100-coalesce(nullif(provider_payload->>'fees_kobo','')::bigint,0)),0)::numeric/100 from private.area_payment_orders where status='paid'),
  'unique_payers',(select count(distinct user_id)::bigint from private.area_payment_orders where status='paid'),
  'repeat_payers',(select count(*)::bigint from (select user_id from private.area_payment_orders where status='paid' group by user_id having count(*)>=2) p),
  'repeat_payer_rate_percent',(select coalesce(round(100.0*count(*)/nullif((select count(distinct user_id) from private.area_payment_orders where status='paid'),0),1),0) from (select user_id from private.area_payment_orders where status='paid' group by user_id having count(*)>=2) p),
  'average_payment_ngn',(select coalesce(round(avg(amount_ngn),2),0) from private.area_payment_orders where status='paid'),
  'revenue_per_payer_ngn',(select coalesce(round(sum(amount_ngn)::numeric/nullif(count(distinct user_id),0),2),0) from private.area_payment_orders where status='paid'),
  'payer_conversion_percent',(select coalesce(round(100.0*(select count(distinct user_id) from private.area_payment_orders where status='paid')/nullif((select count(*) from public.profiles),0),2),0)),
  'active_payers_30d',(select count(distinct user_id)::bigint from private.area_payment_orders where status='paid' and paid_at>=now()-interval '30 days'),
  'gross_payments_30d_ngn',(select coalesce(sum(amount_ngn),0)::bigint from private.area_payment_orders where status='paid' and paid_at>=now()-interval '30 days'),
  'package_mix',(select coalesce(jsonb_object_agg(package_key,orders),'{}'::jsonb) from (select package_key,count(*)::bigint as orders from private.area_payment_orders where status='paid' and order_type='topup' group by package_key) m),
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
