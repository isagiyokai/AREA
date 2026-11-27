drop view if exists public.community_case_tallies;
create or replace function public.get_community_case_tallies(p_case_ids uuid[])
returns table(case_id uuid,total_votes integer,uphold_votes integer,dismiss_votes integer)
language plpgsql security definer set search_path=''
as $function$
begin
 if auth.uid() is null then raise exception 'Sign in to view community vote counts.'; end if;
 return query
 select c.id,count(v.voter_id)::integer,count(v.voter_id) filter(where v.uphold)::integer,count(v.voter_id) filter(where not v.uphold)::integer
 from public.community_cases c left join public.community_case_votes v on v.case_id=c.id
 where c.id=any(coalesce(p_case_ids,array[]::uuid[])) group by c.id;
end;
$function$;
revoke all on function public.get_community_case_tallies(uuid[]) from public,anon;
grant execute on function public.get_community_case_tallies(uuid[]) to authenticated;
create index if not exists community_case_votes_voter_idx on public.community_case_votes(voter_id);
create index if not exists community_cases_opened_by_idx on public.community_cases(opened_by);
create index if not exists community_cases_reporter_idx on public.community_cases(reporter_id);
create index if not exists content_reports_reporter_idx on public.content_reports(reporter_id);
create index if not exists content_reports_reviewed_by_idx on public.content_reports(reviewed_by);
create index if not exists poll_votes_user_idx on public.poll_votes(user_id);
create index if not exists post_reactions_user_idx on public.post_reactions(user_id);