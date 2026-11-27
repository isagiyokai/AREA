create or replace function public.select_free_slums_entry()
returns jsonb language plpgsql security definer set search_path=''
as $function$
declare v_user uuid:=auth.uid();v_grade text;v_active boolean;
begin
 if v_user is null then raise exception 'Sign in to choose your AREA entry.';end if;
 if exists(select 1 from public.profiles where id=v_user and area_entry_tier is not null) then raise exception 'Your entry tier has already been selected.';end if;
 select grade_title,active into v_grade,v_active from public.area_entry_tiers where tier_key='slums_street_material';
 if v_grade is null or not v_active then raise exception 'The free Slums entry is currently unavailable.';end if;
 update public.profiles set area_class='slums',area_grade=v_grade,area_entry_tier='slums_street_material',updated_at=now() where id=v_user;
 return jsonb_build_object('area_class','slums','area_grade',v_grade,'entry_tier','slums_street_material','price_ngn',0,'starting_ac',0);
end;$function$;
revoke all on function public.select_free_slums_entry() from public,anon;grant execute on function public.select_free_slums_entry() to authenticated;