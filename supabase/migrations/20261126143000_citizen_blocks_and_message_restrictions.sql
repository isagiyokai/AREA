create table if not exists public.user_blocks(
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references public.profiles(id) on delete cascade,
 blocked_user_id uuid not null references public.profiles(id) on delete cascade,
 created_at timestamptz not null default now(),
 constraint user_blocks_no_self check(user_id<>blocked_user_id),
 constraint user_blocks_unique unique(user_id,blocked_user_id)
);
create index if not exists user_blocks_blocked_idx on public.user_blocks(blocked_user_id,user_id);
alter table public.user_blocks enable row level security;
create policy "citizens read own blocks" on public.user_blocks for select to authenticated using(user_id=(select auth.uid()));
create policy "citizens create own blocks" on public.user_blocks for insert to authenticated with check(user_id=(select auth.uid()) and blocked_user_id<>(select auth.uid()));
create policy "citizens remove own blocks" on public.user_blocks for delete to authenticated using(user_id=(select auth.uid()));
grant select,insert,delete on public.user_blocks to authenticated;
create or replace function private.area_prevent_blocked_direct_message()
returns trigger language plpgsql security definer set search_path=''
as $function$
begin
 if exists(select 1 from public.user_blocks b where
   (b.user_id=new.sender_id and b.blocked_user_id=new.recipient_id)
   or (b.user_id=new.recipient_id and b.blocked_user_id=new.sender_id)) then
   raise exception 'This conversation is unavailable because one citizen has blocked the other.';
 end if;
 return new;
end;
$function$;
revoke all on function private.area_prevent_blocked_direct_message() from public,anon,authenticated;
drop trigger if exists area_prevent_blocked_direct_message on public.direct_messages;
create trigger area_prevent_blocked_direct_message before insert on public.direct_messages for each row execute function private.area_prevent_blocked_direct_message();
create or replace function public.can_exchange_messages(p_other_id uuid)
returns boolean language sql stable security definer set search_path=''
as $function$
 select (select auth.uid()) is not null and p_other_id is not null and p_other_id<>(select auth.uid())
 and not exists(select 1 from public.user_blocks b where
  (b.user_id=(select auth.uid()) and b.blocked_user_id=p_other_id)
  or (b.user_id=p_other_id and b.blocked_user_id=(select auth.uid())));
$function$;
revoke all on function public.can_exchange_messages(uuid) from public,anon;
grant execute on function public.can_exchange_messages(uuid) to authenticated;
