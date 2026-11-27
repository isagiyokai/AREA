create or replace function public.owner_set_agbero_stamp_duty(p_territory_id uuid,p_stamp_duty_ac bigint)
returns void language plpgsql security definer set search_path=''
as $function$
begin
 if p_stamp_duty_ac is null or p_stamp_duty_ac<0 or p_stamp_duty_ac>1000000000 then raise exception 'Enter a valid stamp duty.';end if;
 if not exists(select 1 from public.agbero_territories where id=p_territory_id and owner_id=auth.uid() and active=true) then raise exception 'Only the territory owner can change its stamp duty.';end if;
 update public.agbero_territories set stamp_duty_ac=p_stamp_duty_ac where id=p_territory_id;
end;$function$;
revoke all on function public.owner_set_agbero_stamp_duty(uuid,bigint) from public,anon;
grant execute on function public.owner_set_agbero_stamp_duty(uuid,bigint) to authenticated;