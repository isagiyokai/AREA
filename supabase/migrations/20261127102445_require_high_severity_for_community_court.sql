alter table public.content_reports add column if not exists severity text not null default 'normal' check(severity in('low','normal','high','critical'));
alter table public.community_cases add column if not exists severity text not null default 'high' check(severity in('high','critical'));
create or replace function public.admin_set_report_severity(p_report_id uuid,p_severity text)
returns void language plpgsql security definer set search_path=''
as $function$
begin
 if not public.is_area_admin() then raise exception 'Owner access required.';end if;
 if p_severity not in('low','normal','high','critical') then raise exception 'Choose a valid severity.';end if;
 update public.content_reports set severity=p_severity where id=p_report_id and status in('open','under_review');
 if not found then raise exception 'Only active reports can be reclassified.';end if;
end;$function$;
revoke all on function public.admin_set_report_severity(uuid,text) from public,anon;
grant execute on function public.admin_set_report_severity(uuid,text) to authenticated;
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
 if v_report.severity not in('high','critical') then raise exception 'Only high or critical severity cases can go to the community court.';end if;
 select case when v_report.target_type='profile' then v_report.target_id when v_report.target_type='post' then(select p.author_id from public.posts p where p.id=v_report.target_id) when v_report.target_type='reply' then(select r.author_id from public.replies r where r.id=v_report.target_id) else null end into v_target;
 if v_target is null then raise exception 'The reported citizen could not be identified.';end if;
 if v_target=v_report.reporter_id then raise exception 'A citizen cannot be tried for reporting themselves.';end if;
 insert into public.community_cases(source_report_id,target_user_id,reporter_id,opened_by,reason,summary,severity,ac_penalty_requested)
 values(v_report.id,v_target,v_report.reporter_id,auth.uid(),v_report.reason,'A reported conduct case is before the community. Review the stated reason and vote on whether the conduct should be upheld.',v_report.severity,p_ac_penalty)
 returning id into v_case_id;
 update public.content_reports set status='under_review',reviewed_at=now(),reviewed_by=auth.uid() where id=v_report.id;
 return v_case_id;
exception when unique_violation then raise exception 'This report has already been sent to the community.';
end;$function$;
revoke all on function public.open_community_case(uuid,bigint) from public,anon;
grant execute on function public.open_community_case(uuid,bigint) to authenticated;
create or replace function public.get_area_admin_overview()
returns jsonb language plpgsql stable security definer set search_path=''
as $function$
declare v_result jsonb;
begin
 if not public.is_area_admin() then raise exception 'Not authorized.';end if;
 select jsonb_build_object(
  'citizens',(select count(*) from public.profiles),'posts',(select count(*) from public.posts),
  'replies',(select count(*) from public.replies),'messages',(select count(*) from public.direct_messages),
  'open_reports',(select count(*) from public.content_reports where status in('open','under_review')),
  'recent_citizens',coalesce((select jsonb_agg(x) from(select p.id,p.username,p.display_name,p.area_class,p.created_at from public.profiles p order by p.created_at desc limit 8)x),'[]'::jsonb),
  'recent_posts',coalesce((select jsonb_agg(x) from(select po.id,po.content,po.created_at,pr.username,pr.display_name from public.posts po join public.profiles pr on pr.id=po.author_id order by po.created_at desc limit 8)x),'[]'::jsonb),
  'reports',coalesce((select jsonb_agg(x) from(select r.id,r.target_type,r.target_id,r.reason,r.details,r.status,r.severity,r.created_at,reporter.username reporter_username,target.username target_username,reply.post_id target_post_id from public.content_reports r join public.profiles reporter on reporter.id=r.reporter_id left join public.profiles target on r.target_type='profile' and target.id=r.target_id left join public.replies reply on r.target_type='reply' and reply.id=r.target_id where r.status in('open','under_review') order by r.created_at desc limit 20)x),'[]'::jsonb)
 ) into v_result;
 return v_result;
end;$function$;
revoke all on function public.get_area_admin_overview() from public,anon;
grant execute on function public.get_area_admin_overview() to authenticated;