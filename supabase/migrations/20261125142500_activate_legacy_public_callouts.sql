create or replace function public.notify_argument_challenge_status()
returns trigger language plpgsql security definer set search_path to ''
as $function$
begin
  if old.status='pending' and new.status in ('active','declined','expired') then
    insert into public.notifications(recipient_id,actor_id,notification_type,message,post_id,challenge_id)
    values(
      new.challenger_id,new.challenged_id,'argument_response',
      case new.status
        when 'active' then 'Your public callout is now live. The other citizen can answer or walk away.'
        when 'declined' then 'Your sparring invitation was declined.'
        else 'Your sparring invitation expired.'
      end,
      new.post_id,new.id
    );
  end if;
  return new;
end;
$function$;

update public.argument_challenges
set status = case when expires_at > now() then 'active' else 'expired' end,
    accepted_at = case when expires_at > now() then coalesce(accepted_at, now()) else accepted_at end,
    ended_at = case when expires_at <= now() then coalesce(ended_at, now()) else ended_at end
where status = 'pending';

update public.notifications n
set message = case when ac.status='active'
  then 'A public callout is live. Answer, ignore or walk away.'
  else 'That older callout has expired.' end
from public.argument_challenges ac
where n.challenge_id=ac.id and n.notification_type='argument_invitation';