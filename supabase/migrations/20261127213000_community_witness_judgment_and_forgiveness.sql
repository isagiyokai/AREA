alter table public.community_cases
 add column if not exists phase text not null default 'judgment' check(phase in('witnessing','judgment')),
 add column if not exists discussion_post_id uuid references public.posts(id) on delete set null,
 add column if not exists offended_user_id uuid references public.profiles(id) on delete set null,
 add column if not exists apology_text text,
 add column if not exists apology_submitted_at timestamptz,
 add column if not exists apology_accepted_at timestamptz,
 add column if not exists reinstated_at timestamptz;

create table if not exists public.community_case_witness_reports(
 id uuid primary key default gen_random_uuid(),case_id uuid not null references public.community_cases(id) on delete cascade,
 reporter_id uuid not null references auth.users(id) on delete cascade,
 reporter_role text not null check(reporter_role in('participant','observer')),
 report_weight smallint not null check(report_weight in(1,2)),reason text not null,details text,
 created_at timestamptz not null default now(),unique(case_id,reporter_id)
);
create index if not exists community_case_witness_reports_case_idx on public.community_case_witness_reports(case_id,created_at);
alter table public.community_case_witness_reports enable row level security;
create policy "Citizens can read witness reports" on public.community_case_witness_reports for select to authenticated using(true);
grant select on public.community_case_witness_reports to authenticated;

create table if not exists public.community_case_witness_votes(
 case_id uuid not null references public.community_cases(id) on delete cascade,
 voter_id uuid not null references auth.users(id) on delete cascade,
 supports_hearing boolean not null,created_at timestamptz not null default now(),primary key(case_id,voter_id)
);
alter table public.community_case_witness_votes enable row level security;
create policy "Citizens read their own witness votes" on public.community_case_witness_votes for select to authenticated using(voter_id=(select auth.uid()));
grant select on public.community_case_witness_votes to authenticated;

insert into public.area_economy_settings(setting_key,setting_value)
values('community_forgiveness_return_fee_ac',500000) on conflict(setting_key) do nothing;

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
  insert into public.content_reports(reporter_id,target_type,target_id,reason,details,status,severity)
  values(v_user,'post',p_post_id,p_reason,nullif(left(coalesce(p_details,''),1000),''),'under_review','high') returning id into v_report_id;
  if v_offended is not null and v_case.offended_user_id is null then update public.community_cases set offended_user_id=v_offended where id=v_case_id;end if;
 end if;
 insert into public.community_case_witness_reports(case_id,reporter_id,reporter_role,report_weight,reason,details)
 values(coalesce(v_case.id,v_case_id),v_user,v_role,v_weight,p_reason,nullif(left(coalesce(p_details,''),1000),'')) on conflict(case_id,reporter_id) do nothing;
 return coalesce(v_case.id,v_case_id);
end;$function$;
revoke all on function public.submit_community_witness_report(uuid,uuid,text,text,boolean) from public,anon;
grant execute on function public.submit_community_witness_report(uuid,uuid,text,text,boolean) to authenticated;

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
 if v_user=v_case.target_user_id or v_user=v_case.reporter_id or exists(select 1 from public.community_case_witness_reports where case_id=p_case_id and reporter_id=v_user) then raise exception 'A reported citizen or reporting citizen cannot judge this stage.';end if;
 if not exists(select 1 from public.profiles p where p.id=v_user and p.created_at<=now()-interval '24 hours') then raise exception 'Your account must be at least 24 hours old to vote.';end if;
 if not(exists(select 1 from public.posts p where p.author_id=v_user and p.created_at>now()-interval '30 days') or exists(select 1 from public.replies r where r.author_id=v_user and r.created_at>now()-interval '30 days')) then raise exception 'Only recently active citizens can vote.';end if;
 if exists(select 1 from public.user_blocks b where(b.user_id=v_user and b.blocked_user_id=v_case.target_user_id)or(b.user_id=v_case.target_user_id and b.blocked_user_id=v_user)) then raise exception 'A block exists between you and this citizen; you cannot vote on this case.';end if;
 insert into public.community_case_witness_votes(case_id,voter_id,supports_hearing) values(p_case_id,v_user,p_supports_hearing)
 on conflict(case_id,voter_id) do update set supports_hearing=excluded.supports_hearing,created_at=now();
end;$function$;
revoke all on function public.vote_community_witness_case(uuid,boolean) from public,anon;
grant execute on function public.vote_community_witness_case(uuid,boolean) to authenticated;

create or replace function public.resolve_community_witness_case(p_case_id uuid)
returns jsonb language plpgsql security definer set search_path=''
as $function$
declare v_case public.community_cases;v_total integer;v_yes integer;v_weight integer;v_reporters integer;
begin
 if auth.uid() is null then raise exception 'Sign in to close a community review.';end if;
 select * into v_case from public.community_cases where id=p_case_id for update;
 if v_case.id is null or v_case.phase<>'witnessing' or v_case.status<>'voting' then raise exception 'This witness review is no longer active.';end if;
 if v_case.vote_closes_at>now() then raise exception 'The witness review is still open.';end if;
 select count(*)::int,count(*) filter(where supports_hearing)::int into v_total,v_yes from public.community_case_witness_votes where case_id=p_case_id;
 select coalesce(sum(report_weight),0),count(distinct reporter_id) into v_weight,v_reporters from public.community_case_witness_reports where case_id=p_case_id;
 if v_weight<3 or v_reporters<2 or v_total<3 then update public.community_cases set status='insufficient_votes',resolved_at=now() where id=p_case_id;return jsonb_build_object('status','insufficient_votes','total_votes',v_total);end if;
 if v_yes::numeric/v_total<0.60 then update public.community_cases set status='dismissed',resolved_at=now() where id=p_case_id;return jsonb_build_object('status','dismissed','votes',v_total,'supports_hearing',v_yes);end if;
 update public.community_cases set phase='judgment',vote_closes_at=now()+interval '24 hours',resolved_at=null where id=p_case_id;
 return jsonb_build_object('status','hearing_authorized','phase','judgment','votes',v_total,'supports_hearing',v_yes);
end;$function$;
revoke all on function public.resolve_community_witness_case(uuid) from public,anon;
grant execute on function public.resolve_community_witness_case(uuid) to authenticated;

create or replace function public.vote_community_case(p_case_id uuid,p_uphold boolean)
returns void language plpgsql security definer set search_path=''
as $function$
declare v_user uuid:=auth.uid();v_case public.community_cases;
begin
 if v_user is null then raise exception 'Sign in to vote.';end if;
 select * into v_case from public.community_cases where id=p_case_id;
 if v_case.id is null or v_case.phase<>'judgment' or v_case.status<>'voting' or v_case.vote_closes_at<=now() then raise exception 'This Wolves judgment is closed.';end if;
 if v_case.target_user_id=v_user or v_case.reporter_id=v_user or v_case.offended_user_id=v_user then raise exception 'The reported citizen and directly involved citizens cannot judge this case.';end if;
 if not exists(select 1 from public.profiles p where p.id=v_user and p.created_at<=now()-interval '24 hours') then raise exception 'Your account must be at least 24 hours old to vote.';end if;
 if not(exists(select 1 from public.posts p where p.author_id=v_user and p.created_at>now()-interval '30 days') or exists(select 1 from public.replies r where r.author_id=v_user and r.created_at>now()-interval '30 days')) then raise exception 'Only recently active citizens can vote.';end if;
 if exists(select 1 from public.user_blocks b where(b.user_id=v_user and b.blocked_user_id=v_case.target_user_id)or(b.user_id=v_case.target_user_id and b.blocked_user_id=v_user)) then raise exception 'A block exists between you and this citizen; you cannot vote on this case.';end if;
 insert into public.community_case_votes(case_id,voter_id,uphold) values(p_case_id,v_user,p_uphold) on conflict(case_id,voter_id) do update set uphold=excluded.uphold,created_at=now();
end;$function$;
revoke all on function public.vote_community_case(uuid,boolean) from public,anon;
grant execute on function public.vote_community_case(uuid,boolean) to authenticated;

create or replace function public.resolve_community_case(p_case_id uuid)
returns jsonb language plpgsql security definer set search_path=''
as $function$
declare v_case public.community_cases;v_total integer;v_yes integer;v_no integer;v_collected bigint:=0;v_pool bigint:=0;v_share bigint:=0;v_voters integer:=0;v_vote record;
begin
 if auth.uid() is null then raise exception 'Sign in to close a community vote.';end if;
 select * into v_case from public.community_cases where id=p_case_id for update;
 if v_case.id is null or v_case.phase<>'judgment' or v_case.status<>'voting' then raise exception 'This case is no longer awaiting a Wolves verdict.';end if;
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
revoke all on function public.resolve_community_case(uuid) from public,anon;
grant execute on function public.resolve_community_case(uuid) to authenticated;

create or replace function public.request_community_apology(p_case_id uuid,p_apology text)
returns void language plpgsql security definer set search_path=''
as $function$
declare v_case public.community_cases;
begin
 if auth.uid() is null then raise exception 'Sign in first.';end if;
 if length(trim(coalesce(p_apology,'')))<10 or length(p_apology)>1000 then raise exception 'Write an apology between 10 and 1,000 characters.';end if;
 select * into v_case from public.community_cases where id=p_case_id for update;
 if v_case.id is null or v_case.target_user_id<>auth.uid() or v_case.status<>'upheld' then raise exception 'Only the citizen serving this case can submit an apology.';end if;
 if v_case.offended_user_id is null then raise exception 'This case has no directly identified offended citizen to receive an apology.';end if;
 if v_case.apology_accepted_at is not null then raise exception 'This apology has already been resolved.';end if;
 update public.community_cases set apology_text=trim(p_apology),apology_submitted_at=now() where id=p_case_id;
end;$function$;
revoke all on function public.request_community_apology(uuid,text) from public,anon;
grant execute on function public.request_community_apology(uuid,text) to authenticated;

create or replace function public.accept_community_apology(p_case_id uuid)
returns jsonb language plpgsql security definer set search_path=''
as $function$
declare v_case public.community_cases;v_fee bigint;v_balance bigint;v_area bigint;v_pool bigint;v_share bigint;v_voters integer;v_vote record;
begin
 if auth.uid() is null then raise exception 'Sign in first.';end if;
 select * into v_case from public.community_cases where id=p_case_id for update;
 if v_case.id is null or v_case.offended_user_id<>auth.uid() or v_case.status<>'upheld' or v_case.apology_submitted_at is null then raise exception 'Only the directly offended citizen can accept this apology.';end if;
 if v_case.apology_accepted_at is not null then raise exception 'This apology has already been accepted.';end if;
 select setting_value into v_fee from public.area_economy_settings where setting_key='community_forgiveness_return_fee_ac';v_fee:=coalesce(v_fee,500000);
 insert into private.wallet_accounts(user_id,balance_ac) values(v_case.target_user_id,0) on conflict(user_id) do nothing;
 perform 1 from private.wallet_accounts where user_id=v_case.target_user_id for update;
 select balance_ac into v_balance from private.wallet_accounts where user_id=v_case.target_user_id;
 if v_balance<v_fee then raise exception 'Forgiveness is accepted, but return costs % AC. This citizen currently has % AC.',v_fee,v_balance;end if;
 update private.wallet_accounts set balance_ac=balance_ac-v_fee,updated_at=now() where user_id=v_case.target_user_id;
 insert into private.ac_ledger(from_user_id,amount_ac,transaction_type,note) values(v_case.target_user_id,v_fee,'penance','Forgiveness return fee for Wolves case '||p_case_id::text);
 select setting_value into v_area from public.area_economy_settings where setting_key='community_penance_area_share_percent';v_area:=coalesce(v_area,30);
 v_pool:=v_fee-floor(v_fee*v_area/100.0)::bigint;
 select count(*)::int into v_voters from public.community_case_votes where case_id=p_case_id;
 if v_voters>0 then v_share:=floor(v_pool/v_voters);end if;
 if v_share>0 then for v_vote in select voter_id from public.community_case_votes where case_id=p_case_id loop
  insert into private.wallet_accounts(user_id,balance_ac) values(v_vote.voter_id,0) on conflict(user_id) do nothing;
  update private.wallet_accounts set balance_ac=balance_ac+v_share,updated_at=now() where user_id=v_vote.voter_id;
  insert into private.ac_ledger(to_user_id,amount_ac,transaction_type,note) values(v_vote.voter_id,v_share,'reward','Community jury share for forgiveness case '||p_case_id::text);
 end loop;end if;
 update public.community_cases set apology_accepted_at=now(),reinstated_at=now(),ac_penalty_collected=ac_penalty_collected+v_fee where id=p_case_id;
 update public.citizen_penances set ends_at=now(),served_at=now() where case_id=p_case_id and user_id=v_case.target_user_id and served_at is null;
 return jsonb_build_object('status','reinstated','fee_ac',v_fee,'area_share_ac',floor(v_fee*v_area/100.0)::bigint,'jury_pool_ac',v_pool);
end;$function$;
revoke all on function public.accept_community_apology(uuid) from public,anon;
grant execute on function public.accept_community_apology(uuid) to authenticated;
