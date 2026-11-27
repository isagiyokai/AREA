insert into public.area_economy_settings(setting_key,setting_value)
values('community_penance_fee_ac',1000) on conflict(setting_key) do nothing;

create or replace function public.admin_update_area_economy_setting(p_key text,p_value bigint)
returns void language plpgsql security definer set search_path=''
as $function$
begin
 if not public.is_area_admin() then raise exception 'Owner access required.';end if;
 if p_key not in('gbas_gbos_level_2_cost_ac','gbas_gbos_level_3_cost_ac','ac_per_ngn','agbero_default_stamp_duty_ac','agbero_area_share_percent','community_penance_area_share_percent','community_forgiveness_return_fee_ac','community_penance_fee_ac') then raise exception 'Unknown economy setting.';end if;
 if p_value is null or p_value<0 or p_value>1000000000000 then raise exception 'Enter a valid non-negative value.';end if;
 if p_key in('agbero_area_share_percent','community_penance_area_share_percent') and p_value>100 then raise exception 'Share percentages must be between 0 and 100.';end if;
 if p_key='ac_per_ngn' and p_value>1000000 then raise exception 'AC per naira is outside the supported range.';end if;
 insert into public.area_economy_settings(setting_key,setting_value,updated_at) values(p_key,p_value,now())
 on conflict(setting_key) do update set setting_value=excluded.setting_value,updated_at=now();
end;$function$;
revoke all on function public.admin_update_area_economy_setting(text,bigint) from public,anon;
grant execute on function public.admin_update_area_economy_setting(text,bigint) to authenticated;

create or replace function public.submit_community_witness_report(p_post_id uuid,p_target_user_id uuid,p_reason text,p_details text default null,p_offended boolean default false)
returns uuid language plpgsql security definer set search_path=''
as $function$
declare v_user uuid:=auth.uid();v_post public.posts;v_role text;v_weight smallint;v_case public.community_cases;v_report_id uuid;v_case_id uuid;v_offended uuid:=null;v_penalty bigint;
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
  if exists(select 1 from public.community_cases where discussion_post_id=p_post_id and target_user_id=p_target_user_id and phase='judgment' and status='voting') then
   raise exception 'This citizen is already before the Wolves for this conversation.';
  end if;
  select setting_value into v_penalty from public.area_economy_settings where setting_key='community_penance_fee_ac';
  v_penalty:=coalesce(v_penalty,1000);
  insert into public.content_reports(reporter_id,target_type,target_id,reason,details,status,severity)
  values(v_user,'post',p_post_id,p_reason,nullif(left(coalesce(p_details,''),1000),''),'under_review','high') returning id into v_report_id;
  insert into public.community_cases(source_report_id,target_user_id,reporter_id,opened_by,reason,summary,severity,discussion_post_id,offended_user_id,phase,status,vote_closes_at,ac_penalty_requested)
  values(v_report_id,p_target_user_id,v_user,v_user,p_reason,'Community witness review. Independent reports carry additional weight; citizens decide whether this conversation should proceed to the Wolves.','high',p_post_id,v_offended,'witnessing','voting',now()+interval '24 hours',v_penalty) returning * into v_case;
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