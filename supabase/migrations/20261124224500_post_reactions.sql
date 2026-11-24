create table if not exists public.post_reactions (
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  reaction_type text not null check (reaction_type in ('valid','cap','laugh','wahala')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (post_id,user_id)
);
create index if not exists post_reactions_post_type_idx on public.post_reactions(post_id,reaction_type);
alter table public.post_reactions enable row level security;
drop policy if exists "Post reactions are publicly readable" on public.post_reactions;
create policy "Post reactions are publicly readable" on public.post_reactions for select to anon,authenticated using (true);
drop policy if exists "Citizens add their own post reactions" on public.post_reactions;
create policy "Citizens add their own post reactions" on public.post_reactions for insert to authenticated with check ((select auth.uid())=user_id);
drop policy if exists "Citizens update their own post reactions" on public.post_reactions;
create policy "Citizens update their own post reactions" on public.post_reactions for update to authenticated using ((select auth.uid())=user_id) with check ((select auth.uid())=user_id);
drop policy if exists "Citizens remove their own post reactions" on public.post_reactions;
create policy "Citizens remove their own post reactions" on public.post_reactions for delete to authenticated using ((select auth.uid())=user_id);
revoke all on public.post_reactions from anon,authenticated;
grant select on public.post_reactions to anon,authenticated;
grant insert,update,delete on public.post_reactions to authenticated;
