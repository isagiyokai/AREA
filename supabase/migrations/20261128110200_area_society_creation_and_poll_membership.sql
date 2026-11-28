create or replace function public.create_area_community(p_name text,p_slug text,p_description text default '')
returns uuid
language plpgsql
security definer
set search_path=''
as $function$
declare
 v_user uuid:=auth.uid();
 v_community_id uuid;
 v_name text:=btrim(coalesce(p_name,''));
 v_slug text:=lower(btrim(coalesce(p_slug,'')));
 v_description text:=btrim(coalesce(p_description,''));
begin
 if v_user is null then raise exception 'Sign in to create a community.'; end if;
 if not exists(select 1 from public.profiles p where p.id=v_user and p.area_entry_tier is not null) then
   raise exception 'Complete your AREA entry before creating a community.';
 end if;
 if exists(select 1 from public.citizen_penances cp where cp.user_id=v_user and cp.ends_at>now()) then
   raise exception 'You cannot create a community while serving an active penance.';
 end if;
 if exists(select 1 from public.agbero_territories t where t.active=true)
    and not exists(select 1 from public.agbero_memberships m where m.citizen_id=v_user and m.status='inside') then
   raise exception 'Enter an active territory before participating in the street.';
 end if;
 if char_length(v_name)<3 or char_length(v_name)>48 then raise exception 'Community name must be 3–48 characters.'; end if;
 if char_length(v_slug)<3 or char_length(v_slug)>48 or v_slug !~ '^[a-z0-9]+(-[a-z0-9]+)*$' then raise exception 'Use a 3–48 character URL name with lowercase letters, numbers and single hyphens.'; end if;
 if char_length(v_description)>280 then raise exception 'Description must be 280 characters or fewer.'; end if;
 insert into public.area_communities(name,slug,description,created_by)
 values(v_name,v_slug,v_description,v_user)
 returning id into v_community_id;
 insert into public.area_community_members(community_id,user_id,role)
 values(v_community_id,v_user,'owner');
 return v_community_id;
end;
$function$;
revoke all on function public.create_area_community(text,text,text) from public,anon;
grant execute on function public.create_area_community(text,text,text) to authenticated;

drop policy if exists "Citizens cast their own votes" on public.poll_votes;
create policy "Citizens cast their own votes" on public.poll_votes for insert to authenticated
with check(
 user_id=(select auth.uid())
 and exists(select 1 from public.post_polls pp join public.posts p on p.id=pp.post_id
   where pp.id=poll_id and (pp.ends_at is null or pp.ends_at>now())
   and (p.community_id is null or exists(select 1 from public.area_community_members cm where cm.community_id=p.community_id and cm.user_id=(select auth.uid())))
 )
);
drop policy if exists "Citizens change their own votes" on public.poll_votes;
create policy "Citizens change their own votes" on public.poll_votes for update to authenticated
using(user_id=(select auth.uid()))
with check(
 user_id=(select auth.uid())
 and exists(select 1 from public.post_polls pp join public.posts p on p.id=pp.post_id
   where pp.id=poll_id and (pp.ends_at is null or pp.ends_at>now())
   and (p.community_id is null or exists(select 1 from public.area_community_members cm where cm.community_id=p.community_id and cm.user_id=(select auth.uid())))
 )
);