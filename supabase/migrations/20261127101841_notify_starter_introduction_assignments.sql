alter table public.notifications add column if not exists introduction_id uuid references public.citizen_introductions(id) on delete cascade;
alter table public.notifications drop constraint if exists notifications_notification_type_check;
alter table public.notifications add constraint notifications_notification_type_check check(notification_type=any(array['argument_invitation'::text,'argument_response'::text,'argument_escalation'::text,'escalation_response'::text,'post_reply'::text,'quote_post'::text,'mention_post'::text,'mention_reply'::text,'direct_message'::text,'community_case_opened'::text,'community_case_resolved'::text,'starter_introduction'::text]));
create index if not exists notifications_introduction_idx on public.notifications(introduction_id) where introduction_id is not null;
create or replace function private.notify_starter_introduction()
returns trigger language plpgsql security definer set search_path=''
as $function$
declare v_requester_name text;
begin
 if new.status='introduced' and new.introduced_id is not null and (tg_op='INSERT' or old.status is distinct from new.status or old.introduced_id is distinct from new.introduced_id) then
  select username into v_requester_name from public.profiles where id=new.requester_id;
  insert into public.notifications(recipient_id,actor_id,notification_type,message,introduction_id) values(new.requester_id,new.introduced_id,'starter_introduction','A Nepo citizen has been introduced to you.',new.id);
  insert into public.notifications(recipient_id,actor_id,notification_type,message,introduction_id) values(new.introduced_id,new.requester_id,'starter_introduction','You are a starter connection for @'||coalesce(v_requester_name,'a citizen')||'.',new.id);
 end if;
 return new;
end;$function$;
revoke all on function private.notify_starter_introduction() from public,anon,authenticated;
drop trigger if exists notify_starter_introduction on public.citizen_introductions;
create trigger notify_starter_introduction after insert or update of status,introduced_id on public.citizen_introductions for each row execute function private.notify_starter_introduction();