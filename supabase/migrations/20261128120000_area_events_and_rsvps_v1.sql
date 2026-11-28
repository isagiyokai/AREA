create table if not exists public.area_events (
 id uuid primary key default gen_random_uuid(),
 title text not null check(char_length(btrim(title)) between 4 and 80),
 description text not null default '' check(char_length(description)<=1200),
 event_type text not null default 'community' check(event_type in ('community','watch_party','meetup','online','campus','other')),
 starts_at timestamptz not null,
 ends_at timestamptz null,
 location_label text not null default '' check(char_length(location_label)<=160),
 community_id uuid null references public.area_communities(id) on delete set null,
 created_by uuid not null references public.profiles(id) on delete restrict,
 created_at timestamptz not null default now(),
 check(ends_at is null or ends_at>starts_at)
);
create table if not exists public.area_event_rsvps (
 event_id uuid not null references public.area_events(id) on delete cascade,
 user_id uuid not null references public.profiles(id) on delete cascade,
 status text not null default 'going' check(status in ('going','interested')),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 primary key(event_id,user_id)
);
create index if not exists area_events_start_idx on public.area_events(starts_at asc);
create index if not exists area_events_creator_idx on public.area_events(created_by,created_at desc);
create index if not exists area_events_community_idx on public.area_events(community_id,starts_at asc) where community_id is not null;
create index if not exists area_event_rsvps_user_idx on public.area_event_rsvps(user_id,event_id);

alter table public.area_events enable row level security;
alter table public.area_event_rsvps enable row level security;
drop policy if exists "AREA events are public" on public.area_events;
create policy "AREA events are public" on public.area_events for select to anon,authenticated using(true);
drop policy if exists "Citizens view their own event RSVPs" on public.area_event_rsvps;
create policy "Citizens view their own event RSVPs" on public.area_event_rsvps for select to authenticated using(user_id=(select auth.uid()));
drop policy if exists "Citizens RSVP for themselves" on public.area_event_rsvps;
create policy "Citizens RSVP for themselves" on public.area_event_rsvps for insert to authenticated
with check(user_id=(select auth.uid()) and exists(
 select 1 from public.area_events e where e.id=event_id and (e.community_id is null or exists(
  select 1 from public.area_community_members cm where cm.community_id=e.community_id and cm.user_id=(select auth.uid())
 ))
));
drop policy if exists "Citizens update their own RSVP" on public.area_event_rsvps;
create policy "Citizens update their own RSVP" on public.area_event_rsvps for update to authenticated
using(user_id=(select auth.uid()))
with check(user_id=(select auth.uid()) and exists(
 select 1 from public.area_events e where e.id=event_id and (e.community_id is null or exists(
  select 1 from public.area_community_members cm where cm.community_id=e.community_id and cm.user_id=(select auth.uid())
 ))
));
drop policy if exists "Citizens cancel their own RSVP" on public.area_event_rsvps;
create policy "Citizens cancel their own RSVP" on public.area_event_rsvps for delete to authenticated using(user_id=(select auth.uid()));
revoke all on public.area_events,public.area_event_rsvps from anon,authenticated;
grant select on public.area_events to anon,authenticated;
grant select,insert,update,delete on public.area_event_rsvps to authenticated;

create or replace function public.create_area_event(
 p_title text,p_description text,p_event_type text,p_starts_at timestamptz,p_ends_at timestamptz default null,
 p_location_label text default '',p_community_id uuid default null
) returns uuid
language plpgsql security definer set search_path=''
as $function$
declare v_user uuid:=auth.uid();v_id uuid;v_title text:=btrim(coalesce(p_title,''));v_type text:=coalesce(p_event_type,'community');
begin
 if v_user is null then raise exception 'Sign in to create an event.'; end if;
 if not exists(select 1 from public.profiles p where p.id=v_user and p.area_entry_tier is not null) then raise exception 'Complete your AREA entry before creating an event.'; end if;
 if exists(select 1 from public.citizen_penances cp where cp.user_id=v_user and cp.ends_at>now()) then raise exception 'You cannot create an event while serving an active penance.'; end if;
 if exists(select 1 from public.agbero_territories t where t.active=true) and not exists(select 1 from public.agbero_memberships m where m.citizen_id=v_user and m.status='inside') then raise exception 'Enter an active territory before participating in the street.'; end if;
 if char_length(v_title)<4 or char_length(v_title)>80 then raise exception 'Event title must be 4–80 characters.'; end if;
 if char_length(coalesce(p_description,''))>1200 then raise exception 'Event description must be 1,200 characters or fewer.'; end if;
 if v_type not in ('community','watch_party','meetup','online','campus','other') then raise exception 'Choose a valid event type.'; end if;
 if p_starts_at is null or p_starts_at<=now() then raise exception 'Choose a future start time.'; end if;
 if p_ends_at is not null and p_ends_at<=p_starts_at then raise exception 'Event end must be after its start.'; end if;
 if char_length(coalesce(p_location_label,''))>160 then raise exception 'Location or meeting link label is too long.'; end if;
 if p_community_id is not null and not exists(select 1 from public.area_community_members cm where cm.community_id=p_community_id and cm.user_id=v_user) then raise exception 'Join the community before creating its event.'; end if;
 insert into public.area_events(title,description,event_type,starts_at,ends_at,location_label,community_id,created_by)
 values(v_title,btrim(coalesce(p_description,'')),v_type,p_starts_at,p_ends_at,btrim(coalesce(p_location_label,'')),p_community_id,v_user)
 returning id into v_id;
 return v_id;
end;
$function$;
revoke all on function public.create_area_event(text,text,text,timestamptz,timestamptz,text,uuid) from public,anon;
grant execute on function public.create_area_event(text,text,text,timestamptz,timestamptz,text,uuid) to authenticated;

create or replace function public.get_area_event_counts()
returns table(event_id uuid,going_count bigint,interested_count bigint)
language sql stable security definer set search_path=''
as $function$
 select e.id,count(r.user_id) filter(where r.status='going')::bigint,
        count(r.user_id) filter(where r.status='interested')::bigint
 from public.area_events e left join public.area_event_rsvps r on r.event_id=e.id
 group by e.id;
$function$;
revoke all on function public.get_area_event_counts() from public;
grant execute on function public.get_area_event_counts() to anon,authenticated;
