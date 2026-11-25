create or replace function public.request_argument_escalation(p_challenge_id uuid, p_requested_intensity smallint)
returns public.argument_escalation_requests
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_user_id uuid := auth.uid();
  v_challenge public.argument_challenges;
  v_result public.argument_escalation_requests;
  v_recent_count integer;
begin
  if v_user_id is null then raise exception 'Sign in to raise the heat.'; end if;
  if p_requested_intensity is null or p_requested_intensity not between 2 and 3 then
    raise exception 'Choose a valid intensity level.';
  end if;
  select * into v_challenge from public.argument_challenges
  where id = p_challenge_id and status = 'active'
    and v_user_id in (challenger_id, challenged_id)
  for update;
  if v_challenge.id is null then raise exception 'This public callout is no longer active.'; end if;
  if p_requested_intensity <= v_challenge.intensity then
    raise exception 'Choose an intensity higher than the current level.';
  end if;
  select count(*) into v_recent_count from public.argument_escalation_requests
  where requester_id = v_user_id and created_at > now() - interval '24 hours';
  if v_recent_count >= 10 then raise exception 'You have reached today’s escalation limit. Try again later.'; end if;
  update public.argument_escalation_requests
  set status = 'cancelled', responded_at = now(), responded_by = v_user_id
  where challenge_id = p_challenge_id and status = 'pending';
  update public.argument_challenges set intensity = p_requested_intensity
  where id = p_challenge_id returning * into v_challenge;
  insert into public.argument_escalation_requests(
    challenge_id, requester_id, requested_intensity, status, responded_at, responded_by
  ) values (
    p_challenge_id, v_user_id, p_requested_intensity, 'accepted', now(), v_user_id
  ) returning * into v_result;
  return v_result;
end;
$function$;

create or replace function public.notify_argument_escalation_insert()
returns trigger language plpgsql security definer set search_path to ''
as $function$
declare v_challenge public.argument_challenges;
begin
  select * into v_challenge from public.argument_challenges where id = new.challenge_id;
  if v_challenge.id is not null then
    insert into public.notifications(recipient_id,actor_id,notification_type,message,post_id,challenge_id,escalation_request_id)
    values (
      case when new.requester_id=v_challenge.challenger_id then v_challenge.challenged_id else v_challenge.challenger_id end,
      new.requester_id,'argument_escalation',
      case new.requested_intensity when 2 then 'Your sparring partner raised this exchange to Heated.'
        else 'Your sparring partner raised this exchange to Full Wahala.' end,
      v_challenge.post_id,v_challenge.id,new.id
    );
  end if;
  return new;
end;
$function$;