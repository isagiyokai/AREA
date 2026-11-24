-- AREA citizen follow graph.
-- Applied to the connected Supabase project before this migration was committed.

create table if not exists public.follows (
  follower_id uuid not null references public.profiles(id) on delete cascade,
  followed_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (follower_id, followed_id),
  constraint follows_no_self_follow check (follower_id <> followed_id)
);

create index if not exists follows_followed_created_idx
  on public.follows(followed_id, created_at desc);
create index if not exists follows_follower_created_idx
  on public.follows(follower_id, created_at desc);

alter table public.follows enable row level security;

drop policy if exists "Follow relationships are publicly readable" on public.follows;
create policy "Follow relationships are publicly readable"
  on public.follows for select to anon, authenticated using (true);

drop policy if exists "Citizens can follow from their own account" on public.follows;
create policy "Citizens can follow from their own account"
  on public.follows for insert to authenticated
  with check (follower_id=(select auth.uid()) and follower_id<>followed_id);

drop policy if exists "Citizens can unfollow from their own account" on public.follows;
create policy "Citizens can unfollow from their own account"
  on public.follows for delete to authenticated
  using (follower_id=(select auth.uid()));

revoke all on public.follows from anon, authenticated;
grant select on public.follows to anon, authenticated;
grant insert, delete on public.follows to authenticated;
