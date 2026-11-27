drop policy if exists "Citizens can read witness reports" on public.community_case_witness_reports;
create policy "Citizens read their own witness reports" on public.community_case_witness_reports for select to authenticated using(reporter_id=(select auth.uid()));
revoke select on public.community_case_witness_reports from anon,authenticated;
grant select on public.community_case_witness_reports to authenticated;

create or replace function public.get_community_witness_tallies(p_case_ids uuid[])
returns table(case_id uuid,total_votes integer,support_votes integer,oppose_votes integer,report_weight integer,report_count integer)
language sql stable security definer set search_path=''
as $function$
 select c.id,count(distinct v.voter_id)::integer,
        count(distinct v.voter_id) filter(where v.supports_hearing)::integer,
        count(distinct v.voter_id) filter(where not v.supports_hearing)::integer,
        coalesce(max(r.weighted),0)::integer,coalesce(max(r.reporters),0)::integer
 from public.community_cases c
 left join public.community_case_witness_votes v on v.case_id=c.id
 left join lateral(select sum(report_weight) weighted,count(*) reporters from public.community_case_witness_reports where community_case_witness_reports.case_id=c.id) r on true
 where c.id=any(p_case_ids) group by c.id;
$function$;
revoke all on function public.get_community_witness_tallies(uuid[]) from public,anon;
grant execute on function public.get_community_witness_tallies(uuid[]) to authenticated;