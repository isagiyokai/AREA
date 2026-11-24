-- AREA notifications for sparring invitations and mutual-consent escalation.
-- Applied to the connected Supabase project before this migration was committed.

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  actor_id uuid references public.profiles(id) on delete set null,
  notification_type text not null check (notification_type in ('argument_invitation','argument_response','argument_escalation','escalation_response')),
  message text not null check (char_length(message) between 1 and 240),
  post_id uuid references public.posts(id) on delete cascade,
  challenge_id uuid references public.argument_challenges(id) on delete cascade,
  escalation_request_id uuid references public.argument_escalation_requests(id) on delete cascade,
  created_at timestamptz not null default now(),
  read_at timestamptz
);
create index if not exists notifications_recipient_created_idx on public.notifications(recipient_id,created_at desc);
create index if not exists notifications_post_idx on public.notifications(post_id);

alter table public.notifications enable row level security;
drop policy if exists "Citizens read their own notifications" on public.notifications;
create policy "Citizens read their own notifications" on public.notifications for select to authenticated using (recipient_id=auth.uid());
drop policy if exists "Citizens mark their own notifications read" on public.notifications;
create policy "Citizens mark their own notifications read" on public.notifications for update to authenticated using (recipient_id=auth.uid()) with check (recipient_id=auth.uid());
revoke all on public.notifications from anon,authenticated;
grant select on public.notifications to authenticated;
grant update(read_at) on public.notifications to authenticated;

create or replace function public.notify_argument_challenge_insert()
returns trigger language plpgsql security definer set search_path=''
as $$
begin
 insert into public.notifications(recipient_id,actor_id,notification_type,message,post_id,challenge_id)
 values(new.challenged_id,new.challenger_id,'argument_invitation','You have a new sparring invitation.',new.post_id,new.id);
 return new;
end;
$$;

create or replace function public.notify_argument_challenge_status()
returns trigger language plpgsql security definer set search_path=''
as $$
begin
 if old.status='pending' and new.status in ('active','declined','expired') then
  insert into public.notifications(recipient_id,actor_id,notification_type,message,post_id,challenge_id)
  values(new.challenger_id,new.challenged_id,'argument_response',
   case new.status when 'active' then 'Your sparring invitation was accepted.' when 'declined' then 'Your sparring invitation was declined.' else 'Your sparring invitation expired.' end,
   new.post_id,new.id);
 end if;
 return new;
end;
$$;

create or replace function public.notify_argument_escalation_insert()
returns trigger language plpgsql security definer set search_path=''
as $$
declare v_challenge public.argument_challenges;
begin
 select * into v_challenge from public.argument_challenges where id=new.challenge_id;
 if v_challenge.id is not null then
  insert into public.notifications(recipient_id,actor_id,notification_type,message,post_id,challenge_id,escalation_request_id)
  values(case when new.requester_id=v_challenge.challenger_id then v_challenge.challenged_id else v_challenge.challenger_id end,
   new.requester_id,'argument_escalation',
   case new.requested_intensity when 2 then 'Your sparring partner requested Heated intensity.' else 'Your sparring partner requested Full Wahala intensity.' end,
   v_challenge.post_id,v_challenge.id,new.id);
 end if;
 return new;
end;
$$;

create or replace function public.notify_argument_escalation_status()
returns trigger language plpgsql security definer set search_path=''
as $$
declare v_challenge public.argument_challenges;
begin
 if old.status='pending' and new.status in ('accepted','declined','expired') then
  select * into v_challenge from public.argument_challenges where id=new.challenge_id;
  if v_challenge.id is not null then
   insert into public.notifications(recipient_id,actor_id,notification_type,message,post_id,challenge_id,escalation_request_id)
   values(new.requester_id,new.responded_by,'escalation_response',
    case new.status when 'accepted' then 'Your intensity increase was accepted.' when 'declined' then 'Your intensity increase was declined.' else 'Your intensity request expired.' end,
    v_challenge.post_id,v_challenge.id,new.id);
  end if;
 end if;
 return new;
end;
$$;

drop trigger if exists argument_challenge_notify_insert on public.argument_challenges;
create trigger argument_challenge_notify_insert after insert on public.argument_challenges for each row execute function public.notify_argument_challenge_insert();
drop trigger if exists argument_challenge_notify_status on public.argument_challenges;
create trigger argument_challenge_notify_status after update of status on public.argument_challenges for each row when (old.status is distinct from new.status) execute function public.notify_argument_challenge_status();
drop trigger if exists argument_escalation_notify_insert on public.argument_escalation_requests;
create trigger argument_escalation_notify_insert after insert on public.argument_escalation_requests for each row execute function public.notify_argument_escalation_insert();
drop trigger if exists argument_escalation_notify_status on public.argument_escalation_requests;
create trigger argument_escalation_notify_status after update of status on public.argument_escalation_requests for each row when (old.status is distinct from new.status) execute function public.notify_argument_escalation_status();

revoke all on function public.notify_argument_challenge_insert() from public,anon,authenticated;
revoke all on function public.notify_argument_challenge_status() from public,anon,authenticated;
revoke all on function public.notify_argument_escalation_insert() from public,anon,authenticated;
revoke all on function public.notify_argument_escalation_status() from public,anon,authenticated;
