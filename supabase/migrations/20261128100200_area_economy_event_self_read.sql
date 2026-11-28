create policy "Citizens can inspect their own economy event throttle"
on private.area_economy_events for select to authenticated
using (user_id = (select auth.uid()));
grant select on private.area_economy_events to authenticated;