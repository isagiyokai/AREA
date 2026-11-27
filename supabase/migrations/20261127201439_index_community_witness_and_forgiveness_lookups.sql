create index if not exists community_case_witness_reports_reporter_idx on public.community_case_witness_reports(reporter_id);
create index if not exists community_case_witness_votes_voter_idx on public.community_case_witness_votes(voter_id);
create index if not exists community_cases_discussion_post_idx on public.community_cases(discussion_post_id) where discussion_post_id is not null;
create index if not exists community_cases_offended_user_idx on public.community_cases(offended_user_id) where offended_user_id is not null;