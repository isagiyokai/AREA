-- AREA opt-in sparring and mutual-consent escalation system.
-- Applied to the connected Supabase project before this migration was committed.

create table if not exists public.argument_challenges (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  challenger_id uuid not null references public.profiles(id) on delete cascade,
  challenged_id uuid not null references public.profiles(id) on delete cascade,
  intensity smallint not null check (intensity between 1 and 3),
  status text not null default 'pending'
    check (status in ('pending','active','declined','ended','expired')),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '24 hours'),
  accepted_at timestamptz,
  ended_at timestamptz,
  ended_by uuid references public.profiles(id) on delete set null,
  constraint argument_challenges_distinct_users check (challenger_id <> challenged_id)
);

create index if not exists argument_challenges_post_created_idx
  on public.argument_challenges(post_id, created_at desc);
create index if not exists argument_challenges_target_status_idx
  on public.argument_challenges(challenged_id, status, created_at desc);
create index if not exists argument_challenges_challenger_created_idx
  on public.argument_challenges(challenger_id, created_at desc);
create index if not exists argument_challenges_ended_by_idx
  on public.argument_challenges(ended_by);
create unique index if not exists argument_challenges_one_live_pair_per_post_idx
  on public.argument_challenges(post_id, least(challenger_id, challenged_id), greatest(challenger_id, challenged_id))
  where status in ('pending','active');

alter table public.argument_challenges enable row level security;
drop policy if exists "Argument challenges are publicly readable" on public.argument_challenges;
create policy "Argument challenges are publicly readable"
  on public.argument_challenges for select to anon, authenticated using (true);
revoke all on public.argument_challenges from anon, authenticated;
grant select on public.argument_challenges to anon, authenticated;

create or replace function public.create_argument_challenge(p_post_id uuid,p_opponent_id uuid,p_intensity smallint)
returns public.argument_challenges
language plpgsql security definer set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_result public.argument_challenges;
  v_post_author uuid;
  v_recent_count integer;
begin
  if v_user_id is null then raise exception 'You must sign in to challenge someone.'; end if;
  if p_intensity is null or p_intensity not between 1 and 3 then raise exception 'Choose a valid intensity level.'; end if;
  if p_opponent_id is null or p_opponent_id = v_user_id then raise exception 'Choose another citizen to challenge.'; end if;

  select p.author_id into v_post_author from public.posts p where p.id = p_post_id;
  if v_post_author is null then raise exception 'This conversation no longer exists.'; end if;
  if not exists (select 1 from public.profiles pr where pr.id = p_opponent_id) then raise exception 'That citizen could not be found.'; end if;
  if p_opponent_id <> v_post_author and not exists (
    select 1 from public.replies r where r.post_id = p_post_id and r.author_id = p_opponent_id
  ) then raise exception 'You can only challenge a citizen who has joined this conversation.'; end if;

  update public.argument_challenges ac set status='expired',ended_at=now()
  where ac.post_id=p_post_id and ac.status='pending' and ac.expires_at<=now()
    and ((ac.challenger_id=v_user_id and ac.challenged_id=p_opponent_id)
      or (ac.challenger_id=p_opponent_id and ac.challenged_id=v_user_id));

  select count(*) into v_recent_count from public.argument_challenges ac
  where ac.challenger_id=v_user_id and ac.created_at>now()-interval '24 hours';
  if v_recent_count>=10 then raise exception 'You have reached today’s challenge invitation limit. Try again later.'; end if;

  insert into public.argument_challenges(post_id,challenger_id,challenged_id,intensity)
  values(p_post_id,v_user_id,p_opponent_id,p_intensity) returning * into v_result;
  return v_result;
exception when unique_violation then
  raise exception 'There is already an open sparring challenge between these citizens in this conversation.';
end;
$$;

create or replace function public.respond_argument_challenge(p_challenge_id uuid,p_accept boolean)
returns public.argument_challenges
language plpgsql security definer set search_path = ''
as $$
declare v_user_id uuid := auth.uid(); v_result public.argument_challenges;
begin
  if v_user_id is null then raise exception 'You must sign in to respond.'; end if;
  if p_accept is null then raise exception 'Choose whether to accept or decline.'; end if;
  update public.argument_challenges ac
  set status=case when p_accept then 'active' else 'declined' end,
      accepted_at=case when p_accept then now() else null end,
      ended_at=case when p_accept then null else now() end
  where ac.id=p_challenge_id and ac.challenged_id=v_user_id and ac.status='pending' and ac.expires_at>now()
  returning * into v_result;
  if v_result.id is not null then return v_result; end if;
  update public.argument_challenges ac set status='expired',ended_at=now()
  where ac.id=p_challenge_id and ac.challenged_id=v_user_id and ac.status='pending' and ac.expires_at<=now()
  returning * into v_result;
  if v_result.id is not null then return v_result; end if;
  raise exception 'This challenge is unavailable or has expired.';
end;
$$;

create or replace function public.end_argument_challenge(p_challenge_id uuid)
returns public.argument_challenges
language plpgsql security definer set search_path = ''
as $$
declare v_user_id uuid := auth.uid(); v_result public.argument_challenges;
begin
  if v_user_id is null then raise exception 'You must sign in to end a challenge.'; end if;
  update public.argument_challenges ac set status='ended',ended_at=now(),ended_by=v_user_id
  where ac.id=p_challenge_id and v_user_id in (ac.challenger_id,ac.challenged_id) and ac.status in ('pending','active')
  returning * into v_result;
  if v_result.id is null then raise exception 'This challenge is no longer active.'; end if;
  return v_result;
end;
$$;

revoke all on function public.create_argument_challenge(uuid,uuid,smallint) from public,anon;
revoke all on function public.respond_argument_challenge(uuid,boolean) from public,anon;
revoke all on function public.end_argument_challenge(uuid) from public,anon;
grant execute on function public.create_argument_challenge(uuid,uuid,smallint) to authenticated;
grant execute on function public.respond_argument_challenge(uuid,boolean) to authenticated;
grant execute on function public.end_argument_challenge(uuid) to authenticated;

create table if not exists public.argument_escalation_requests (
  id uuid primary key default gen_random_uuid(),
  challenge_id uuid not null references public.argument_challenges(id) on delete cascade,
  requester_id uuid not null references public.profiles(id) on delete cascade,
  requested_intensity smallint not null check (requested_intensity between 2 and 3),
  status text not null default 'pending'
    check (status in ('pending','accepted','declined','cancelled','expired')),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '30 minutes'),
  responded_at timestamptz,
  responded_by uuid references public.profiles(id) on delete set null
);
create index if not exists argument_escalation_challenge_created_idx
  on public.argument_escalation_requests(challenge_id,created_at desc);
create index if not exists argument_escalation_requester_created_idx
  on public.argument_escalation_requests(requester_id,created_at desc);
create index if not exists argument_escalation_responded_by_idx
  on public.argument_escalation_requests(responded_by);
create unique index if not exists argument_escalation_one_pending_per_challenge_idx
  on public.argument_escalation_requests(challenge_id) where status='pending';

alter table public.argument_escalation_requests enable row level security;
drop policy if exists "Escalation requests are publicly readable" on public.argument_escalation_requests;
create policy "Escalation requests are publicly readable"
  on public.argument_escalation_requests for select to anon,authenticated using (true);
revoke all on public.argument_escalation_requests from anon,authenticated;
grant select on public.argument_escalation_requests to anon,authenticated;

create or replace function public.request_argument_escalation(p_challenge_id uuid,p_requested_intensity smallint)
returns public.argument_escalation_requests
language plpgsql security definer set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_challenge public.argument_challenges;
  v_result public.argument_escalation_requests;
  v_recent_count integer;
begin
  if v_user_id is null then raise exception 'Sign in to request an escalation.'; end if;
  if p_requested_intensity is null or p_requested_intensity not between 2 and 3 then raise exception 'Choose a valid intensity level.'; end if;
  select * into v_challenge from public.argument_challenges
  where id=p_challenge_id and status='active' and v_user_id in (challenger_id,challenged_id) for update;
  if v_challenge.id is null then raise exception 'This sparring exchange is no longer active.'; end if;
  if p_requested_intensity<=v_challenge.intensity then raise exception 'An escalation must be higher than the current intensity.'; end if;

  update public.argument_escalation_requests set status='expired',responded_at=now()
  where challenge_id=p_challenge_id and status='pending' and expires_at<=now();
  select count(*) into v_recent_count from public.argument_escalation_requests
  where requester_id=v_user_id and created_at>now()-interval '24 hours';
  if v_recent_count>=10 then raise exception 'You have reached today’s escalation request limit.'; end if;

  insert into public.argument_escalation_requests(challenge_id,requester_id,requested_intensity)
  values(p_challenge_id,v_user_id,p_requested_intensity) returning * into v_result;
  return v_result;
exception when unique_violation then
  raise exception 'An intensity change is already awaiting a response.';
end;
$$;

create or replace function public.respond_argument_escalation(p_request_id uuid,p_accept boolean)
returns public.argument_escalation_requests
language plpgsql security definer set search_path = ''
as $$
declare v_user_id uuid := auth.uid(); v_request public.argument_escalation_requests; v_challenge public.argument_challenges;
begin
  if v_user_id is null then raise exception 'Sign in to respond.'; end if;
  if p_accept is null then raise exception 'Choose whether to accept or decline.'; end if;

  select er.* into v_request from public.argument_escalation_requests er
  join public.argument_challenges ac on ac.id=er.challenge_id
  where er.id=p_request_id and er.status='pending' and er.expires_at>now()
    and ac.status='active' and v_user_id in (ac.challenger_id,ac.challenged_id) and er.requester_id<>v_user_id
  for update of er;

  if v_request.id is null then
    update public.argument_escalation_requests er
    set status='expired',responded_at=now(),responded_by=v_user_id
    where er.id=p_request_id and er.status='pending' and er.expires_at<=now()
      and exists(select 1 from public.argument_challenges ac where ac.id=er.challenge_id
        and ac.status='active' and v_user_id in (ac.challenger_id,ac.challenged_id) and er.requester_id<>v_user_id)
    returning * into v_request;
    if v_request.id is not null then return v_request; end if;
    raise exception 'This escalation request is unavailable or has expired.';
  end if;

  if p_accept then
    select * into v_challenge from public.argument_challenges where id=v_request.challenge_id for update;
    if v_challenge.status<>'active' or v_request.requested_intensity<=v_challenge.intensity then raise exception 'The exchange has changed. Refresh and try again.'; end if;
    update public.argument_challenges set intensity=v_request.requested_intensity where id=v_request.challenge_id;
  end if;

  update public.argument_escalation_requests
  set status=case when p_accept then 'accepted' else 'declined' end,responded_at=now(),responded_by=v_user_id
  where id=p_request_id returning * into v_request;
  return v_request;
end;
$$;

revoke all on function public.request_argument_escalation(uuid,smallint) from public,anon;
revoke all on function public.respond_argument_escalation(uuid,boolean) from public,anon;
grant execute on function public.request_argument_escalation(uuid,smallint) to authenticated;
grant execute on function public.respond_argument_escalation(uuid,boolean) to authenticated;
