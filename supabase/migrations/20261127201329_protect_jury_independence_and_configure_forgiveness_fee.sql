create or replace function public.admin_update_area_economy_setting(p_key text,p_value bigint)
returns void language plpgsql security definer set search_path=''
as $function$
begin
 if not public.is_area_admin() then raise exception 'Owner access required.';end if;
 if p_key not in('gbas_gbos_level_2_cost_ac','gbas_gbos_level_3_cost_ac','ac_per_ngn','agbero_default_stamp_duty_ac','agbero_area_share_percent','community_penance_area_share_percent','community_forgiveness_return_fee_ac') then raise exception 'Unknown economy setting.';end if;
 if p_value is null or p_value<0 or p_value>1000000000000 then raise exception 'Enter a valid non-negative value.';end if;
 if p_key in('agbero_area_share_percent','community_penance_area_share_percent') and p_value>100 then raise exception 'Share percentages must be between 0 and 100.';end if;
 if p_key='ac_per_ngn' and p_value>1000000 then raise exception 'AC per naira is outside the supported range.';end if;
 insert into public.area_economy_settings(setting_key,setting_value,updated_at) values(p_key,p_value,now())
 on conflict(setting_key) do update set setting_value=excluded.setting_value,updated_at=now();
end;$function$;
revoke all on function public.admin_update_area_economy_setting(text,bigint) from public,anon;
grant execute on function public.admin_update_area_economy_setting(text,bigint) to authenticated;

create or replace function public.vote_community_witness_case(p_case_id uuid,p_supports_hearing boolean)
returns void language plpgsql security definer set search_path=''
as $function$
declare v_user uuid:=auth.uid();v_case public.community_cases;v_weight integer;v_reporters integer;
begin
 if v_user is null then raise exception 'Sign in to vote.';end if;
 select * into v_case from public.community_cases where id=p_case_id;
 if v_case.id is null or v_case.phase<>'witnessing' or v_case.status<>'voting' or v_case.vote_closes_at<=now() then raise exception 'This witness review is closed.';end if;
 select coalesce(sum(report_weight),0),count(distinct reporter_id) into v_weight,v_reporters from public.community_case_witness_reports where case_id=p_case_id;
 if v_weight<3 or v_reporters<2 then raise exception 'The conversation needs more independent reports before a hearing can be voted on.';end if;
 if v_user=v_case.target_user_id or v_user=v_case.reporter_id or exists(select 1 from public.community_case_witness_reports where case_id=p_case_id and reporter_id=v_user)
  or exists(select 1 from public.posts p where p.id=v_case.discussion_post_id and p.author_id=v_user)
  or exists(select 1 from public.replies r where r.post_id=v_case.discussion_post_id and r.author_id=v_user) then
  raise exception 'Citizens directly involved in the conversation or its reports cannot judge this stage.';
 end if;
 if not exists(select 1 from public.profiles p where p.id=v_user and p.created_at<=now()-interval '24 hours') then raise exception 'Your account must be at least 24 hours old to vote.';end if;
 if not(exists(select 1 from public.posts p where p.author_id=v_user and p.created_at>now()-interval '30 days') or exists(select 1 from public.replies r where r.author_id=v_user and r.created_at>now()-interval '30 days')) then raise exception 'Only recently active citizens can vote.';end if;
 if exists(select 1 from public.user_blocks b where(b.user_id=v_user and b.blocked_user_id=v_case.target_user_id)or(b.user_id=v_case.target_user_id and b.blocked_user_id=v_user)) then raise exception 'A block exists between you and this citizen; you cannot vote on this case.';end if;
 insert into public.community_case_witness_votes(case_id,voter_id,supports_hearing) values(p_case_id,v_user,p_supports_hearing)
 on conflict(case_id,voter_id) do update set supports_hearing=excluded.supports_hearing,created_at=now();
end;$function$;
revoke all on function public.vote_community_witness_case(uuid,boolean) from public,anon;
grant execute on function public.vote_community_witness_case(uuid,boolean) to authenticated;

create or replace function public.vote_community_case(p_case_id uuid,p_uphold boolean)
returns void language plpgsql security definer set search_path=''
as $function$
declare v_user uuid:=auth.uid();v_case public.community_cases;
begin
 if v_user is null then raise exception 'Sign in to vote.';end if;
 select * into v_case from public.community_cases where id=p_case_id;
 if v_case.id is null or v_case.phase<>'judgment' or v_case.status<>'voting' or v_case.vote_closes_at<=now() then raise exception 'This Wolves judgment is closed.';end if;
 if v_case.target_user_id=v_user or v_case.reporter_id=v_user or v_case.offended_user_id=v_user
  or exists(select 1 from public.community_case_witness_reports wr where wr.case_id=p_case_id and wr.reporter_id=v_user)
  or exists(select 1 from public.posts p where p.id=v_case.discussion_post_id and p.author_id=v_user)
  or exists(select 1 from public.replies r where r.post_id=v_case.discussion_post_id and r.author_id=v_user) then
  raise exception 'Citizens directly involved in the conversation or its reports cannot judge this case.';
 end if;
 if not exists(select 1 from public.profiles p where p.id=v_user and p.created_at<=now()-interval '24 hours') then raise exception 'Your account must be at least 24 hours old to vote.';end if;
 if not(exists(select 1 from public.posts p where p.author_id=v_user and p.created_at>now()-interval '30 days') or exists(select 1 from public.replies r where r.author_id=v_user and r.created_at>now()-interval '30 days')) then raise exception 'Only recently active citizens can vote.';end if;
 if exists(select 1 from public.user_blocks b where(b.user_id=v_user and b.blocked_user_id=v_case.target_user_id)or(b.user_id=v_case.target_user_id and b.blocked_user_id=v_user)) then raise exception 'A block exists between you and this citizen; you cannot vote on this case.';end if;
 insert into public.community_case_votes(case_id,voter_id,uphold) values(p_case_id,v_user,p_uphold) on conflict(case_id,voter_id) do update set uphold=excluded.uphold,created_at=now();
end;$function$;
revoke all on function public.vote_community_case(uuid,boolean) from public,anon;
grant execute on function public.vote_community_case(uuid,boolean) to authenticated;