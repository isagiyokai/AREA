drop policy if exists "Signed-in citizens read community cases" on public.community_cases;
create policy "Citizens read public community cases" on public.community_cases for select to anon,authenticated using(true);
grant select on public.community_cases to anon,authenticated;
create or replace view public.community_case_tallies with (security_invoker=false) as
select c.id case_id,count(v.voter_id)::integer total_votes,count(v.voter_id) filter(where v.uphold)::integer uphold_votes,count(v.voter_id) filter(where not v.uphold)::integer dismiss_votes
from public.community_cases c left join public.community_case_votes v on v.case_id=c.id group by c.id;
grant select on public.community_case_tallies to authenticated;