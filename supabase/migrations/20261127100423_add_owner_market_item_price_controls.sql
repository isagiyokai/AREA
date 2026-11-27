create or replace function public.admin_set_market_item_price(p_item_id uuid,p_price_ac bigint)
returns void language plpgsql security definer set search_path=''
as $function$
begin
 if not public.is_area_admin() then raise exception 'Owner access required.';end if;
 if p_price_ac is null or p_price_ac<0 or p_price_ac>1000000000 then raise exception 'Enter a valid AC price.';end if;
 update public.area_market_items set price_ac=p_price_ac where id=p_item_id;
 if not found then raise exception 'Market item not found.';end if;
end;$function$;
revoke all on function public.admin_set_market_item_price(uuid,bigint) from public,anon;
grant execute on function public.admin_set_market_item_price(uuid,bigint) to authenticated;