drop policy if exists "Citizens RSVP for themselves" on public.area_event_rsvps;
create policy "Citizens RSVP for themselves" on public.area_event_rsvps for insert to authenticated
with check(user_id=(select auth.uid()) and exists(
 select 1 from public.area_events e where e.id=event_id and e.starts_at>now() and (e.community_id is null or exists(
  select 1 from public.area_community_members cm where cm.community_id=e.community_id and cm.user_id=(select auth.uid())
 ))
));
drop policy if exists "Citizens update their own RSVP" on public.area_event_rsvps;
create policy "Citizens update their own RSVP" on public.area_event_rsvps for update to authenticated
using(user_id=(select auth.uid()))
with check(user_id=(select auth.uid()) and exists(
 select 1 from public.area_events e where e.id=event_id and e.starts_at>now() and (e.community_id is null or exists(
  select 1 from public.area_community_members cm where cm.community_id=e.community_id and cm.user_id=(select auth.uid())
 ))
));