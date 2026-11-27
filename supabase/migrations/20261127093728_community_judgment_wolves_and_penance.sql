create table if not exists public.community_cases (
 id uuid primary key default gen_random_uuid(),source_report_id uuid not null unique references public.content_reports(id) on delete restrict,
 target_user_id uuid not null references public.profiles(id) on delete restrict,reporter_id uuid not null references auth.users(id) on delete restrict,
 opened_by uuid not null references auth.users(id) on delete restrict,reason text not null,
 summary text not null default 'A reported conduct case has been brought before the community.',
 status text not null default 'voting' check(status in('voting','upheld','dismissed','insufficient_votes')),
 vote_closes_at timestamptz not null default(now()+interval '24 hours'),resolved_at timestamptz,penance_until timestamptz,
 ac_penalty_requested bigint not null default 0 check(ac_penalty_requested between 0 and 1000000000),
 ac_penalty_collected bigint not null default 0 check(ac_penalty_collected>=0),
 area_share_percent smallint not null default 30 check(area_share_percent between 0 and 100),created_at timestamptz not null default now()
);
create index if not exists community_cases_status_closes_idx on public.community_cases(status,vote_closes_at desc);
create index if not exists community_cases_target_created_idx on public.community_cases(target_user_id,created_at desc);
create table if not exists public.community_case_votes(case_id uuid not null references public.community_cases(id) on delete cascade,voter_id uuid not null references auth.users(id) on delete cascade,uphold boolean not null,created_at timestamptz not null default now(),primary key(case_id,voter_id));
create table if not exists public.citizen_penances(id uuid primary key default gen_random_uuid(),case_id uuid not null unique references public.community_cases(id) on delete restrict,user_id uuid not null references auth.users(id) on delete cascade,starts_at timestamptz not null default now(),ends_at timestamptz not null,served_at timestamptz,created_at timestamptz not null default now(),check(ends_at>starts_at));
create index if not exists citizen_penances_user_ends_idx on public.citizen_penances(user_id,ends_at desc);
alter table public.community_cases enable row level security;alter table public.community_case_votes enable row level security;alter table public.citizen_penances enable row level security;
create policy "Citizens read public community cases" on public.community_cases for select to anon,authenticated using(true);
create policy "Citizens read their own community votes" on public.community_case_votes for select to authenticated using(voter_id=(select auth.uid()));
create policy "Citizens read their own penances" on public.citizen_penances for select to authenticated using(user_id=(select auth.uid()));
grant select on public.community_cases,public.community_case_votes,public.citizen_penances to authenticated;
create or replace view public.community_case_tallies with(security_invoker=false) as select c.id case_id,count(v.voter_id)::integer total_votes,count(v.voter_id) filter(where v.uphold)::integer uphold_votes,count(v.voter_id) filter(where not v.uphold)::integer dismiss_votes from public.community_cases c left join public.community_case_votes v on v.case_id=c.id group by c.id;
grant select on public.community_case_tallies to authenticated;
create or replace view public.citizen_reputation with(security_invoker=true) as
select p.id user_id,greatest(0,100-(count(c.id) filter(where c.status='upheld')::integer*10))::integer reputation_score,count(c.id) filter(where c.status='upheld')::integer upheld_cases,count(c.id) filter(where c.status='dismissed')::integer dismissed_cases,
case when count(c.id) filter(where c.status='upheld')=0 then 'Unjudged' when count(c.id) filter(where c.status='upheld')=1 then 'On notice' when count(c.id) filter(where c.status='upheld') between 2 and 3 then 'Questioned' else 'Low standing' end::text reputation_title
from public.profiles p left join public.community_cases c on c.target_user_id=p.id group by p.id;
grant select on public.citizen_reputation to anon,authenticated;
create or replace function public.open_community_case(p_report_id uuid,p_ac_penalty bigint default 0) returns uuid language plpgsql security definer set search_path='' as $function$
declare v_report public.content_reports;v_target uuid;v_case_id uuid;
begin
 if not public.is_area_admin() then raise exception 'Only AREA moderators can send a report to the Wolves.';end if;
 if p_ac_penalty is null or p_ac_penalty<0 or p_ac_penalty>1000000000 then raise exception 'Invalid AC penance amount.';end if;
 select * into v_report from public.content_reports where id=p_report_id for update;
 if v_report.id is null then raise exception 'Report not found.';end if;
 select case when v_report.target_type='profile' then v_report.target_id when v_report.target_type='post' then(select p.author_id from public.posts p where p.id=v_report.target_id) when v_report.target_type='reply' then(select r.author_id from public.replies r where r.id=v_report.target_id) else null end into v_target;
 if v_target is null then raise exception 'The reported citizen could not be identified.';end if;
 if v_target=v_report.reporter_id then raise exception 'A citizen cannot be tried for reporting themselves.';end if;
 insert into public.community_cases(source_report_id,target_user_id,reporter_id,opened_by,reason,summary,ac_penalty_requested)
 values(v_report.id,v_target,v_report.reporter_id,auth.uid(),v_report.reason,'A reported conduct case is before the community. Review the stated reason and vote on whether the conduct should be upheld.',p_ac_penalty) returning id into v_case_id;
 update public.content_reports set status='under_review',reviewed_at=now(),reviewed_by=auth.uid() where id=v_report.id;
 return v_case_id;
exception when unique_violation then raise exception 'This report has already been sent to the community.';
end;$function$;
revoke all on function public.open_community_case(uuid,bigint) from public,anon;grant execute on function public.open_community_case(uuid,bigint) to authenticated;
create or replace function public.vote_community_case(p_case_id uuid,p_uphold boolean) returns void language plpgsql security definer set search_path='' as $function$
declare v_user uuid:=auth.uid();v_case public.community_cases;
begin
 if v_user is null then raise exception 'Sign in to vote.';end if;
 select * into v_case from public.community_cases where id=p_case_id;
 if v_case.id is null or v_case.status<>'voting' or v_case.vote_closes_at<=now() then raise exception 'This vote is closed.';end if;
 if v_case.target_user_id=v_user or v_case.reporter_id=v_user then raise exception 'The reported citizen and the reporter cannot vote on this case.';end if;
 if not exists(select 1 from public.profiles p where p.id=v_user and p.created_at<=now()-interval '24 hours') then raise exception 'Your account must be at least 24 hours old to vote.';end if;
 if not(exists(select 1 from public.posts p where p.author_id=v_user and p.created_at>now()-interval '30 days') or exists(select 1 from public.replies r where r.author_id=v_user and r.created_at>now()-interval '30 days')) then raise exception 'Only recently active citizens can vote.';end if;
 if exists(select 1 from public.user_blocks b where(b.user_id=v_user and b.blocked_user_id=v_case.target_user_id)or(b.user_id=v_case.target_user_id and b.blocked_user_id=v_user)) then raise exception 'A block exists between you and this citizen; you cannot vote on this case.';end if;
 insert into public.community_case_votes(case_id,voter_id,uphold) values(p_case_id,v_user,p_uphold) on conflict(case_id,voter_id) do update set uphold=excluded.uphold,created_at=now();
end;$function$;
revoke all on function public.vote_community_case(uuid,boolean) from public,anon;grant execute on function public.vote_community_case(uuid,boolean) to authenticated;
create or replace function public.resolve_community_case(p_case_id uuid) returns jsonb language plpgsql security definer set search_path='' as $function$
declare v_case public.community_cases;v_total integer;v_yes integer;v_no integer;v_collected bigint:=0;v_pool bigint:=0;v_share bigint:=0;v_voters integer:=0;v_vote record;
begin
 if auth.uid() is null then raise exception 'Sign in to close a community vote.';end if;
 select * into v_case from public.community_cases where id=p_case_id for update;
 if v_case.id is null or v_case.status<>'voting' then raise exception 'This case is no longer awaiting a verdict.';end if;
 if v_case.vote_closes_at>now() then raise exception 'The vote is still open.';end if;
 select count(*)::int,count(*) filter(where uphold)::int,count(*) filter(where not uphold)::int into v_total,v_yes,v_no from public.community_case_votes where case_id=p_case_id;
 if v_total<3 then update public.community_cases set status='insufficient_votes',resolved_at=now() where id=p_case_id;return jsonb_build_object('status','insufficient_votes','total_votes',v_total);end if;
 if v_yes<=v_no then update public.community_cases set status='dismissed',resolved_at=now() where id=p_case_id;return jsonb_build_object('status','dismissed','uphold_votes',v_yes,'dismiss_votes',v_no);end if;
 update public.community_cases set status='upheld',resolved_at=now(),penance_until=now()+interval '24 hours' where id=p_case_id;
 insert into public.citizen_penances(case_id,user_id,starts_at,ends_at) values(p_case_id,v_case.target_user_id,now(),now()+interval '24 hours') on conflict(case_id) do nothing;
 if v_case.ac_penalty_requested>0 then
  insert into private.wallet_accounts(user_id,balance_ac) values(v_case.target_user_id,0) on conflict(user_id) do nothing;
  perform 1 from private.wallet_accounts where user_id=v_case.target_user_id for update;
  select least(balance_ac,v_case.ac_penalty_requested) into v_collected from private.wallet_accounts where user_id=v_case.target_user_id;
  if v_collected>0 then
   update private.wallet_accounts set balance_ac=balance_ac-v_collected,updated_at=now() where user_id=v_case.target_user_id;
   insert into private.ac_ledger(from_user_id,amount_ac,transaction_type,note) values(v_case.target_user_id,v_collected,'penance','Community penance case '||p_case_id::text);
   select count(*)::int into v_voters from public.community_case_votes where case_id=p_case_id;
   v_pool:=v_collected-floor(v_collected*v_case.area_share_percent/100.0)::bigint;
   if v_voters>0 then v_share:=floor(v_pool/v_voters);end if;
   if v_share>0 then for v_vote in select voter_id from public.community_case_votes where case_id=p_case_id loop
    insert into private.wallet_accounts(user_id,balance_ac) values(v_vote.voter_id,0) on conflict(user_id) do nothing;
    update private.wallet_accounts set balance_ac=balance_ac+v_share,updated_at=now() where user_id=v_vote.voter_id;
    insert into private.ac_ledger(to_user_id,amount_ac,transaction_type,note) values(v_vote.voter_id,v_share,'reward','Community jury share for case '||p_case_id::text);
   end loop;end if;
  end if;
 end if;
 update public.community_cases set ac_penalty_collected=v_collected where id=p_case_id;
 return jsonb_build_object('status','upheld','uphold_votes',v_yes,'dismiss_votes',v_no,'penance_hours',24,'ac_collected',v_collected);
end;$function$;
revoke all on function public.resolve_community_case(uuid) from public,anon;grant execute on function public.resolve_community_case(uuid) to authenticated;
drop policy if exists "Citizens create own posts" on public.posts;
create policy "Citizens create own posts" on public.posts for insert to authenticated with check((select auth.uid())=author_id and not exists(select 1 from public.citizen_penances cp where cp.user_id=(select auth.uid()) and cp.ends_at>now()));
drop policy if exists "Citizens create own replies" on public.replies;
create policy "Citizens create own replies" on public.replies for insert to authenticated with check((select auth.uid())=author_id and not exists(select 1 from public.citizen_penances cp where cp.user_id=(select auth.uid()) and cp.ends_at>now()));
create or replace function public.create_argument_challenge(p_post_id uuid,p_opponent_id uuid,p_intensity smallint) returns public.argument_challenges language plpgsql security definer set search_path='' as $function$
declare v_user_id uuid:=auth.uid();v_result public.argument_challenges;v_post_author uuid;v_recent_count integer;
begin
 if v_user_id is null then raise exception 'You must sign in to make a public callout.';end if;
 if exists(select 1 from public.citizen_penances cp where cp.user_id=v_user_id and cp.ends_at>now()) then raise exception 'You are serving a community penance. You can return to the yard when it ends.';end if;
 if p_intensity is null or p_intensity not between 1 and 3 then raise exception 'Choose a valid intensity level.';end if;
 if p_opponent_id is null or p_opponent_id=v_user_id then raise exception 'Choose another citizen to call out.';end if;
 select p.author_id into v_post_author from public.posts p where p.id=p_post_id;
 if v_post_author is null then raise exception 'This conversation no longer exists.';end if;
 if not exists(select 1 from public.profiles pr where pr.id=p_opponent_id) then raise exception 'That citizen could not be found.';end if;
 if p_opponent_id<>v_post_author and not exists(select 1 from public.replies r where r.post_id=p_post_id and r.author_id=p_opponent_id) then raise exception 'You can only call out a citizen who has joined this conversation.';end if;
 update public.argument_challenges ac set status='expired',ended_at=now() where ac.post_id=p_post_id and ac.status='pending' and ac.expires_at<=now() and((ac.challenger_id=v_user_id and ac.challenged_id=p_opponent_id)or(ac.challenger_id=p_opponent_id and ac.challenged_id=v_user_id));
 select count(*) into v_recent_count from public.argument_challenges ac where ac.challenger_id=v_user_id and ac.created_at>now()-interval '24 hours';
 if v_recent_count>=10 then raise exception 'You have reached today’s callout limit. Try again later.';end if;
 insert into public.argument_challenges(post_id,challenger_id,challenged_id,intensity,status,accepted_at) values(p_post_id,v_user_id,p_opponent_id,p_intensity,'active',now()) returning * into v_result;
 return v_result;
exception when unique_violation then raise exception 'There is already an open callout between these citizens in this conversation.';
end;$function$;
revoke all on function public.create_argument_challenge(uuid,uuid,smallint) from public,anon;grant execute on function public.create_argument_challenge(uuid,uuid,smallint) to authenticated;