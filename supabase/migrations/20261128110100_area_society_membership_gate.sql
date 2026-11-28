create or replace function public.join_area_community(p_community_id uuid)
returns boolean
language plpgsql
security definer
set search_path=''
as $function$
declare v_user uuid:=auth.uid();
begin
 if v_user is null then raise exception 'Sign in to join a community.'; end if;
 if not exists(select 1 from public.profiles p where p.id=v_user and p.area_entry_tier is not null) then
   raise exception 'Complete your AREA entry before joining communities.';
 end if;
 if exists(select 1 from public.citizen_penances cp where cp.user_id=v_user and cp.ends_at>now()) then
   raise exception 'You cannot join a community while serving an active penance.';
 end if;
 if exists(select 1 from public.agbero_territories t where t.active=true)
    and not exists(select 1 from public.agbero_memberships m where m.citizen_id=v_user and m.status='inside') then
   raise exception 'Enter an active territory before participating in the street.';
 end if;
 if not exists(select 1 from public.area_communities c where c.id=p_community_id) then
   raise exception 'Community not found.';
 end if;
 insert into public.area_community_members(community_id,user_id,role)
 values(p_community_id,v_user,'member')
 on conflict(community_id,user_id) do nothing;
 return true;
end;
$function$;
revoke all on function public.join_area_community(uuid) from public,anon;
grant execute on function public.join_area_community(uuid) to authenticated;
revoke insert on public.area_community_members from authenticated;