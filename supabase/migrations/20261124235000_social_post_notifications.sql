alter table public.notifications drop constraint if exists notifications_notification_type_check;
alter table public.notifications add constraint notifications_notification_type_check check(notification_type in ('argument_invitation','argument_response','argument_escalation','escalation_response','post_reply','quote_post'));
create or replace function public.notify_post_reply_insert() returns trigger language plpgsql security definer set search_path='' as $$
declare v_recipient uuid; v_actor_name text;
begin
 select p.author_id into v_recipient from public.posts p where p.id=new.post_id;
 if v_recipient is not null and v_recipient<>new.author_id then
  select coalesce(pr.display_name,'A citizen') into v_actor_name from public.profiles pr where pr.id=new.author_id;
  insert into public.notifications(recipient_id,actor_id,notification_type,message,post_id)
  values(v_recipient,new.author_id,'post_reply',coalesce(v_actor_name,'A citizen')||' replied to your post.',new.post_id);
 end if;
 return new;
end;$$;
create or replace function public.notify_quote_post_insert() returns trigger language plpgsql security definer set search_path='' as $$
declare v_recipient uuid; v_actor_name text;
begin
 if new.quoted_post_id is null then return new; end if;
 select p.author_id into v_recipient from public.posts p where p.id=new.quoted_post_id;
 if v_recipient is not null and v_recipient<>new.author_id then
  select coalesce(pr.display_name,'A citizen') into v_actor_name from public.profiles pr where pr.id=new.author_id;
  insert into public.notifications(recipient_id,actor_id,notification_type,message,post_id)
  values(v_recipient,new.author_id,'quote_post',coalesce(v_actor_name,'A citizen')||' quoted your post.',new.id);
 end if;
 return new;
end;$$;
drop trigger if exists post_reply_notify_insert on public.replies;
create trigger post_reply_notify_insert after insert on public.replies for each row execute function public.notify_post_reply_insert();
drop trigger if exists quote_post_notify_insert on public.posts;
create trigger quote_post_notify_insert after insert on public.posts for each row when(new.quoted_post_id is not null) execute function public.notify_quote_post_insert();
revoke all on function public.notify_post_reply_insert() from public,anon,authenticated;
revoke all on function public.notify_quote_post_insert() from public,anon,authenticated;
