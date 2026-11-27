create or replace function private.apply_community_penance_share()
returns trigger language plpgsql security definer set search_path=''
as $function$
declare v_share bigint;
begin
 select setting_value into v_share from public.area_economy_settings where setting_key='community_penance_area_share_percent';
 new.area_share_percent:=coalesce(v_share,30)::smallint;
 return new;
end;$function$;
revoke all on function private.apply_community_penance_share() from public,anon,authenticated;
drop trigger if exists community_case_share_config on public.community_cases;
create trigger community_case_share_config before insert on public.community_cases for each row execute function private.apply_community_penance_share();