create or replace function public.admin_update_area_entry_tier(p_tier_key text,p_starting_ac bigint,p_privileges jsonb,p_active boolean default true)
returns void language plpgsql security definer set search_path=''
as $function$
begin
 if not public.is_area_admin() then raise exception 'Owner access required.';end if;
 if p_starting_ac is null or p_starting_ac<0 or p_starting_ac>1000000000000 then raise exception 'Enter a valid starting AC balance.';end if;
 if p_privileges is null or jsonb_typeof(p_privileges)<>'object' then raise exception 'Privileges must be a JSON object.';end if;
 update public.area_entry_tiers set starting_ac=p_starting_ac,privileges=p_privileges,active=coalesce(p_active,true) where tier_key=p_tier_key;
 if not found then raise exception 'Entry tier not found.';end if;
end;$function$;
revoke all on function public.admin_update_area_entry_tier(text,bigint,jsonb,boolean) from public,anon;
grant execute on function public.admin_update_area_entry_tier(text,bigint,jsonb,boolean) to authenticated;