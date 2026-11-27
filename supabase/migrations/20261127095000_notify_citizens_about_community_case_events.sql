alter table public.notifications add column if not exists community_case_id uuid references public.community_cases(id) on delete cascade;
alter table public.notifications drop constraint if exists notifications_notification_type_check;
alter table public.notifications add constraint notifications_notification_type_check check(notification_type=any(array['argument_invitation'::text,'argument_response'::text,'argument_escalation'::text,'escalation_response'::text,'post_reply'::text,'quote_post'::text,'mention_post'::text,'mention_reply'::text,'direct_message'::text,'community_case_opened'::text,'community_case_resolved'::text]));
create index if not exists notifications_community_case_idx on public.notifications(community_case_id) where community_case_id is not null;
create or replace function private.notify_community_case_event()
returns trigger language plpgsql security definer set search_path=''
as $function$
declare v_message text;
begin
 if tg_op='INSERT' then
  insert into public.notifications(recipient_id,actor_id,notification_type,message,community_case_id)
  values(new.target_user_id,new.opened_by,'community_case_opened','A report involving you is now before the community court.',new.id);
  if new.reporter_id<>new.target_user_id then
   insert into public.notifications(recipient_id,actor_id,notification_type,message,community_case_id)
   values(new.reporter_id,new.opened_by,'community_case_opened','Your report has been sent to the community court.',new.id);
  end if;
 elsif tg_op='UPDATE' and old.status='voting' and new.status<>'voting' then
  v_message:=case new.status when 'upheld' then 'The community upheld the case. A 24-hour penance has started.' when 'dismissed' then 'The community dismissed the case. No penance applies.' else 'The vote closed without enough participation. No penalty applies.' end;
  insert into public.notifications(recipient_id,notification_type,message,community_case_id) values(new.target_user_id,'community_case_resolved',v_message,new.id);
  if new.reporter_id<>new.target_user_id then
   insert into public.notifications(recipient_id,notification_type,message,community_case_id) values(new.reporter_id,'community_case_resolved',v_message,new.id);
  end if;
 end if;
 return new;
end;$function$;
revoke all on function private.notify_community_case_event() from public,anon,authenticated;
drop trigger if exists community_case_notifications on public.community_cases;
create trigger community_case_notifications after insert or update of status on public.community_cases for each row execute function private.notify_community_case_event();