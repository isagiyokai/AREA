drop policy if exists "Community memberships are public" on public.area_community_members;
create policy "Citizens view their own community memberships" on public.area_community_members
for select to authenticated using(user_id=(select auth.uid()));
revoke select on public.area_community_members from anon;
grant select on public.area_community_members to authenticated;

create or replace function public.get_area_community_counts()
returns table(community_id uuid,member_count bigint)
language sql
stable
security definer
set search_path=''
as $function$
 select c.id,count(m.user_id)::bigint
 from public.area_communities c
 left join public.area_community_members m on m.community_id=c.id
 group by c.id;
$function$;
revoke all on function public.get_area_community_counts() from public;
grant execute on function public.get_area_community_counts() to anon,authenticated;

drop policy if exists "Citizens add their own post reactions" on public.post_reactions;
create policy "Citizens add their own post reactions" on public.post_reactions for insert to authenticated
with check(
 user_id=(select auth.uid())
 and exists(select 1 from public.posts p where p.id=post_id and (
   p.community_id is null or exists(select 1 from public.area_community_members cm where cm.community_id=p.community_id and cm.user_id=(select auth.uid()))
 ))
);
drop policy if exists "Citizens update their own post reactions" on public.post_reactions;
create policy "Citizens update their own post reactions" on public.post_reactions for update to authenticated
using(user_id=(select auth.uid()))
with check(
 user_id=(select auth.uid())
 and exists(select 1 from public.posts p where p.id=post_id and (
   p.community_id is null or exists(select 1 from public.area_community_members cm where cm.community_id=p.community_id and cm.user_id=(select auth.uid()))
 ))
);