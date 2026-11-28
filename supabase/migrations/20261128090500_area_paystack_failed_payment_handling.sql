-- Mark signed/verified Paystack failures so pending orders do not accumulate.
create or replace function public.fail_ac_payment_order(p_reference text,p_reason text default null)
returns void language plpgsql security invoker set search_path=''
as $function$
begin
 if current_user<>'service_role' then raise exception 'Payment settlement service access required.';end if;
 update private.area_payment_orders set status='failed',
  provider_payload=coalesce(provider_payload,'{}'::jsonb)||jsonb_build_object('failure_reason',left(coalesce(p_reason,'Payment failed'),160))
 where provider_reference=p_reference and status='pending' and provider='paystack';
end;$function$;
revoke all on function public.fail_ac_payment_order(text,text) from public,anon,authenticated;
grant execute on function public.fail_ac_payment_order(text,text) to service_role;
