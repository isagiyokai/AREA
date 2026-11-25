create or replace function public.notify_direct_message()
returns trigger language plpgsql security definer set search_path=''
as $function$
begin
 insert into public.notifications(recipient_id,actor_id,notification_type,message)
 values(new.recipient_id,new.sender_id,'direct_message','sent you a private message.');
 return new;
end;
$function$;
revoke all on function public.notify_direct_message() from public,anon,authenticated;
drop trigger if exists direct_message_notification on public.direct_messages;
create trigger direct_message_notification after insert on public.direct_messages for each row execute function public.notify_direct_message();