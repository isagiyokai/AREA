create table if not exists public.area_communities (
 id uuid primary key default gen_random_uuid(),
 name text not null check (char_length(btrim(name)) between 3 and 48),
 slug text not null unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$' and char_length(slug) between 3 and 48),
 description text not null default '' check (char_length(description) <= 280),
 created_by uuid not null references public.profiles(id) on delete restrict,
 created_at timestamptz not null default now()
);
create table if not exists public.area_community_members (
 community_id uuid not null references public.area_communities(id) on delete cascade,
 user_id uuid not null references public.profiles(id) on delete cascade,
 role text not null default 'member' check (role in ('owner','moderator','member')),
 joined_at timestamptz not null default now(),
 primary key(community_id,user_id)
);
alter table public.posts add column if not exists community_id uuid references public.area_communities(id) on delete set null;
create index if not exists area_communities_created_idx on public.area_communities(created_at desc);
create index if not exists area_community_members_user_idx on public.area_community_members(user_id,joined_at desc);
create index if not exists posts_community_created_idx on public.posts(community_id,created_at desc) where community_id is not null;

alter table public.area_communities enable row level security;
alter table public.area_community_members enable row level security;
drop policy if exists "Communities are public" on public.area_communities;
create policy "Communities are public" on public.area_communities for select to anon,authenticated using(true);
drop policy if exists "Community memberships are public" on public.area_community_members;
create policy "Community memberships are public" on public.area_community_members for select to anon,authenticated using(true);
drop policy if exists "Citizens join communities as members" on public.area_community_members;
create policy "Citizens join communities as members" on public.area_community_members for insert to authenticated
with check(user_id=(select auth.uid()) and role='member');
drop policy if exists "Citizens leave communities they joined" on public.area_community_members;
create policy "Citizens leave communities they joined" on public.area_community_members for delete to authenticated
using(user_id=(select auth.uid()) and role='member');

revoke all on public.area_communities,public.area_community_members from anon,authenticated;
grant select on public.area_communities,public.area_community_members to anon,authenticated;
grant insert,delete on public.area_community_members to authenticated;

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
 if char_length(v_name)<3 or char_length(v_name)>48 then raise exception 'Community name must be 3–48 characters.'; end if;
 if char_length(v_slug)<3 or char_length(v_slug)>48 or v_slug !~ '^[a-z0-9]+(-[a-z0-9]+)*$' then raise exception 'Use a 3–48 character URL name with lowercase letters, numbers and single hyphens.'; end if;
 if char_length(v_description)>280 then raise exception 'Description must be 280 characters or fewer.'; end if;
 if exists(select 1 from public.profiles p where p.id=v_user and exists(select 1 from public.citizen_penances cp where cp.user_id=p.id and cp.ends_at>now())) then
   raise exception 'You cannot create a community while serving an active penance.';
 end if;
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

drop policy if exists "Citizens create own posts" on public.posts;
create policy "Citizens create own posts" on public.posts for insert to authenticated
with check(
 author_id=(select auth.uid())
 and not exists(select 1 from public.citizen_penances cp where cp.user_id=(select auth.uid()) and cp.ends_at>now())
 and ((not exists(select 1 from public.agbero_territories t where t.active=true))
   or exists(select 1 from public.agbero_memberships m where m.citizen_id=(select auth.uid()) and m.status='inside'))
 and (community_id is null or exists(
   select 1 from public.area_community_members cm
   where cm.community_id=posts.community_id and cm.user_id=(select auth.uid())
 ))
);

drop policy if exists "Citizens create own replies" on public.replies;
create policy "Citizens create own replies" on public.replies for insert to authenticated
with check(
 author_id=(select auth.uid())
 and not exists(select 1 from public.citizen_penances cp where cp.user_id=(select auth.uid()) and cp.ends_at>now())
 and ((not exists(select 1 from public.agbero_territories t where t.active=true))
   or exists(select 1 from public.agbero_memberships m where m.citizen_id=(select auth.uid()) and m.status='inside'))
 and exists(
   select 1 from public.posts p
   where p.id=replies.post_id and (
     p.community_id is null or exists(
       select 1 from public.area_community_members cm
       where cm.community_id=p.community_id and cm.user_id=(select auth.uid())
     )
   )
 )
);
