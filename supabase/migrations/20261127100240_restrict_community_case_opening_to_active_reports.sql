create or replace function public.open_community_case(p_report_id uuid,p_ac_penalty bigint default 0)
returns uuid language plpgsql security definer set search_path=''
as $function$
declare v_report public.content_reports;v_target uuid;v_case_id uuid;
begin
 if not public.is_area_admin() then raise exception 'Only AREA moderators can send a report to the Wolves.';end if;
 if p_ac_penalty is null or p_ac_penalty<0 or p_ac_penalty>1000000000 then raise exception 'Invalid AC penance amount.';end if;
 select * into v_report from public.content_reports where id=p_report_id for update;
 if v_report.id is null then raise exception 'Report not found.';end if;
 if v_report.status not in('open','under_review') then raise exception 'Only open or under-review reports can be sent to the community.';end if;
 select case when v_report.target_type='profile' then v_report.target_id when v_report.target_type='post' then(select p.author_id from public.posts p where p.id=v_report.target_id) when v_report.target_type='reply' then(select r.author_id from public.replies r where r.id=v_report.target_id) else null end into v_target;
 if v_target is null then raise exception 'The reported citizen could not be identified.';end if;
 if v_target=v_report.reporter_id then raise exception 'A citizen cannot be tried for reporting themselves.';end if;
 insert into public.community_cases(source_report_id,target_user_id,reporter_id,opened_by,reason,summary,ac_penalty_requested)
 values(v_report.id,v_target,v_report.reporter_id,auth.uid(),v_report.reason,'A reported conduct case is before the community. Review the stated reason and vote on whether the conduct should be upheld.',p_ac_penalty) returning id into v_case_id;
 update public.content_reports set status='under_review',reviewed_at=now(),reviewed_by=auth.uid() where id=v_report.id;
 return v_case_id;
exception when unique_violation then raise exception 'This report has already been sent to the community.';
end;$function$;
revoke all on function public.open_community_case(uuid,bigint) from public,anon;
grant execute on function public.open_community_case(uuid,bigint) to authenticated;