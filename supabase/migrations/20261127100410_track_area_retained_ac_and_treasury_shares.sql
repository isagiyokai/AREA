create or replace function public.get_area_treasury_overview()
returns jsonb language plpgsql security definer set search_path=''
as $function$
declare v_result jsonb;
begin
 if not public.is_area_admin() then raise exception 'Owner access required.';end if;
 select jsonb_build_object(
  'wallet_count',(select count(*)::bigint from private.wallet_accounts),
  'outstanding_ac',(select coalesce(sum(balance_ac),0)::bigint from private.wallet_accounts),
  'gift_volume_ac',(select coalesce(sum(amount_ac),0)::bigint from private.ac_ledger where transaction_type='gift'),
  'reward_volume_ac',(select coalesce(sum(amount_ac),0)::bigint from private.ac_ledger where transaction_type='reward'),
  'community_jury_paid_ac',(select coalesce(sum(amount_ac),0)::bigint from private.ac_ledger where transaction_type='reward' and note like 'Community jury share%'),
  'penance_collected_ac',(select coalesce(sum(amount_ac),0)::bigint from private.ac_ledger where transaction_type='penance'),
  'fees_collected_ac',(select coalesce(sum(amount_ac),0)::bigint from private.ac_ledger where transaction_type='fee'),
  'agbero_area_share_ac',(select coalesce(sum(amount_ac),0)::bigint from private.ac_ledger where transaction_type='fee' and to_user_id is null and note like 'AREA share of Agbero stamp duty:%'),
  'escalation_fee_ac',(select coalesce(sum(amount_ac),0)::bigint from private.ac_ledger where transaction_type='fee' and to_user_id is null and note like 'Gbas Gbos escalation%'),
  'market_purchase_volume_ac',(select coalesce(sum(amount_ac),0)::bigint from private.ac_ledger where transaction_type='purchase'),
  'area_retained_ac',(select coalesce(sum(amount_ac),0)::bigint from private.ac_ledger where transaction_type='fee' and to_user_id is null)+(select coalesce(sum(amount_ac),0)::bigint from private.ac_ledger where transaction_type='purchase')+(select coalesce(sum(amount_ac),0)::bigint from private.ac_ledger where transaction_type='penance')-(select coalesce(sum(amount_ac),0)::bigint from private.ac_ledger where transaction_type='reward' and note like 'Community jury share%'),
  'refunds_ac',(select coalesce(sum(amount_ac),0)::bigint from private.ac_ledger where transaction_type='refund')
 ) into v_result;
 return v_result;
end;$function$;
revoke all on function public.get_area_treasury_overview() from public,anon;
grant execute on function public.get_area_treasury_overview() to authenticated;