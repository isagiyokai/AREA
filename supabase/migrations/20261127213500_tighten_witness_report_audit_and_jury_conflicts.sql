create or replace function public.submit_community_witness_report(p_post_id uuid,p_target_user_id uuid,p_reason text,p_details text default null,p_offended boolean default false)
returns uuid language plpgsql security definer set search_path=''
as $function$
declare v_user uuid:=auth.uid();v_post public.posts;v_role text;v_weight smallint;v_case public.community_cases;v_report_id uuid;v_case_id uuid;v_offended uuid:=null;
begin
 if v_user is null then raise exception 'Sign in to report this conversation.';end if;
 if p_reason not in('threats','harassment','bullying','doxxing','private_information','other') then raise exception 'Choose a valid report reason.';end if;
 select * into v_post from public.posts where id=p_post_id;
 if v_post.id is null then raise exception 'Conversation not found.';end if;
 if p_target_user_id is null or p_target_user_id=v_user then raise exception 'Invalid citizen to report.';end if;
 if p_target_user_id<>v_post.author_id and not exists(select 1 from public.replies r where r.post_id=p_post_id and r.author_id=p_target_user_id) then raise exception 'That citizen is not part of this conversation.';end if;
 if exists(select 1 from public.posts p where p.id=p_post_id and p.author_id=v_user) or exists(select 1 from public.replies r where r.post_id=p_post_id and r.author_id=v_user) then
  v_role:='participant';v_weight:=1;if coalesce(p_offended,false) then v_offended:=v_user;end if;
 else
  v_role:='observer';v_weight:=2;if coalesce(p_offended,false) then raise exception 'Only a participant in this conversation can identify themselves as directly affected.';end if;
 end if;
 perform pg_advisory_xact_lock(hashtext(p_post_id::text||':'||p_target_user_id::text));
 select * into v_case from public.community_cases where discussion_post_id=p_post_id and target_user_id=p_target_user_id and status='voting' and phase='witnessing' order by created_at desc limit 1 for update;
 if v_case.id is null then
  insert into public.content_reports(reporter_id,target_type,target_id,reason,details,status,severity)
  values(v_user,'post',p_post_id,p_reason,nullif(left(coalesce(p_details,''),1000),''),'under_review','high') returning id into v_report_id;
  insert into public.community_cases(source_report_id,target_user_id,reporter_id,opened_by,reason,summary,severity,discussion_post_id,offended_user_id,phase,status,vote_closes_at)
  values(v_report_id,p_target_user_id,v_user,v_user,p_reason,'Community witness review. Independent reports carry additional weight; citizens decide whether this conversation should proceed to the Wolves.','high',p_post_id,v_offended,'witnessing','voting',now()+interval '24 hours') returning * into v_case;
 else
  v_case_id:=v_case.id;
  if v_offended is not null and v_case.offended_user_id is null then update public.community_cases set offended_user_id=v_offended where id=v_case_id;end if;
 end if;
 insert into public.community_case_witness_reports(case_id,reporter_id,reporter_role,report_weight,reason,details)
 values(coalesce(v_case.id,v_case_id),v_user,v_role,v_weight,p_reason,nullif(left(coalesce(p_details,''),1000),'')) on conflict(case_id,reporter_id) do nothing;
 return coalesce(v_case.id,v_case_id);
end;$function$;
revoke all on function public.submit_community_witness_report(uuid,uuid,text,text,boolean) from public,anon;
grant execute on function public.submit_community_witness_report(uuid,uuid,text,text,boolean) to authenticated;

create or replace function public.vote_community_case(p_case_id uuid,p_uphold boolean)
returns void language plpgsql security definer set search_path=''
as $function$
declare v_user uuid:=auth.uid();v_case public.community_cases;
begin
 if v_user is null then raise exception 'Sign in to vote.';end if;
 select * into v_case from public.community_cases where id=p_case_id;
 if v_case.id is null or v_case.phase<>'judgment' or v_case.status<>'voting' or v_case.vote_closes_at<=now() then raise exception 'This Wolves judgment is closed.';end if;
 if v_case.target_user_id=v_user or v_case.reporter_id=v_user or v_case.offended_user_id=v_user or exists(select 1 from public.community_case_witness_reports wr where wr.case_id=p_case_id and wr.reporter_id=v_user) then raise exception 'The reported citizen and directly involved or reporting citizens cannot judge this case.';end if;
 if not exists(select 1 from public.profiles p where p.id=v_user and p.created_at<=now()-interval '24 hours') then raise exception 'Your account must be at least 24 hours old to vote.';end if;
 if not(exists(select 1 from public.posts p where p.author_id=v_user and p.created_at>now()-interval '30 days') or exists(select 1 from public.replies r where r.author_id=v_user and r.created_at>now()-interval '30 days')) then raise exception 'Only recently active citizens can vote.';end if;
 if exists(select 1 from public.user_blocks b where(b.user_id=v_user and b.blocked_user_id=v_case.target_user_id)or(b.user_id=v_case.target_user_id and b.blocked_user_id=v_user)) then raise exception 'A block exists between you and this citizen; you cannot vote on this case.';end if;
 insert into public.community_case_votes(case_id,voter_id,uphold) values(p_case_id,v_user,p_uphold) on conflict(case_id,voter_id) do update set uphold=excluded.uphold,created_at=now();
end;$function$;
revoke all on function public.vote_community_case(uuid,boolean) from public,anon;
grant execute on function public.vote_community_case(uuid,boolean) to authenticated;