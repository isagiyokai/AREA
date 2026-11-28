create table if not exists public.post_reposts (
 post_id uuid not null references public.posts(id) on delete cascade,
 user_id uuid not null references public.profiles(id) on delete cascade,
 created_at timestamptz not null default now(),
 primary key(post_id,user_id)
);
create index if not exists post_reposts_user_created_idx on public.post_reposts(user_id,created_at desc);
create index if not exists post_reposts_post_created_idx on public.post_reposts(post_id,created_at desc);
alter table public.post_reposts enable row level security;
drop policy if exists "Post reposts are public" on public.post_reposts;
create policy "Post reposts are public" on public.post_reposts for select to anon,authenticated using(true);
drop policy if exists "Citizens repost as themselves" on public.post_reposts;
create policy "Citizens repost as themselves" on public.post_reposts for insert to authenticated
with check(
 user_id=(select auth.uid())
 and not exists(select 1 from public.citizen_penances cp where cp.user_id=(select auth.uid()) and cp.ends_at>now())
 and ((not exists(select 1 from public.agbero_territories t where t.active=true))
   or exists(select 1 from public.agbero_memberships m where m.citizen_id=(select auth.uid()) and m.status='inside'))
 and exists(select 1 from public.posts p where p.id=post_id and (
   p.community_id is null or exists(select 1 from public.area_community_members cm where cm.community_id=p.community_id and cm.user_id=(select auth.uid()))
 ))
);
drop policy if exists "Citizens undo their own reposts" on public.post_reposts;
create policy "Citizens undo their own reposts" on public.post_reposts for delete to authenticated
using(user_id=(select auth.uid()));
revoke all on public.post_reposts from anon,authenticated;
grant select on public.post_reposts to anon,authenticated;
grant insert,delete on public.post_reposts to authenticated;
