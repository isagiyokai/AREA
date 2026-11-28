-- Service-role-only RPC used after Paystack server-side verification.
create or replace function public.settle_verified_ac_payment(
 p_reference text,p_provider_transaction_id text,p_amount_kobo bigint,p_currency text,
 p_paid_at timestamptz,p_provider_payload jsonb default '{}'::jsonb
) returns jsonb language sql security invoker set search_path=''
as $function$
 select private.credit_ac_from_verified_payment(
  p_reference,p_provider_transaction_id,p_amount_kobo,p_currency,p_paid_at,p_provider_payload
 );
$function$;
revoke all on function public.settle_verified_ac_payment(text,text,bigint,text,timestamptz,jsonb) from public,anon,authenticated;
grant execute on function public.settle_verified_ac_payment(text,text,bigint,text,timestamptz,jsonb) to service_role;
