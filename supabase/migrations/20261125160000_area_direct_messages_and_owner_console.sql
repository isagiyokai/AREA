create schema if not exists private;

create table if not exists public.direct_messages (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references public.profiles(id) on delete cascade,
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  body text not null check (char_length(btrim(body)) between 1 and 2000),
  created_at timestamptz not null default now(),
  read_at timestamptz,
  constraint direct_messages_no_self check (sender_id <> recipient_id)
);
create index if not exists direct_messages_sender_created_idx on public.direct_messages(sender_id, created_at desc);
create index if not exists direct_messages_recipient_created_idx on public.direct_messages(recipient_id, created_at desc);
alter table public.direct_messages enable row level security;
drop policy if exists "participants read direct messages" on public.direct_messages;
create policy "participants read direct messages" on public.direct_messages for select to authenticated using ((select auth.uid()) in (sender_id, recipient_id));
drop policy if exists "sender creates own direct messages" on public.direct_messages;
create policy "sender creates own direct messages" on public.direct_messages for insert to authenticated with check (sender_id=(select auth.uid()) and recipient_id<>(select auth.uid()) and char_length(btrim(body)) between 1 and 2000);
drop policy if exists "recipient marks direct messages read" on public.direct_messages;
create policy "recipient marks direct messages read" on public.direct_messages for update to authenticated using (recipient_id=(select auth.uid())) with check (recipient_id=(select auth.uid()));
grant select,insert on public.direct_messages to authenticated;
grant update(read_at) on public.direct_messages to authenticated;

create table if not exists public.content_reports (
 id uuid primary key default gen_random_uuid(),
 reporter_id uuid not null references public.profiles(id) on delete cascade,
 target_type text not null check (target_type in ('post','reply','profile')),
 target_id uuid not null,
 reason text not null check (reason in ('threats','harassment','doxxing','spam','impersonation','other')),
 details text check (details is null or char_length(details)<=1000),
 status text not null default 'open' check (status in ('open','under_review','resolved','dismissed')),
 created_at timestamptz not null default now(),
 reviewed_at timestamptz,
 reviewed_by uuid references public.profiles(id) on delete set null
);
create index if not exists content_reports_status_created_idx on public.content_reports(status,created_at desc);
alter table public.content_reports enable row level security;
drop policy if exists "citizens submit reports" on public.content_reports;
create policy "citizens submit reports" on public.content_reports for insert to authenticated with check (reporter_id=(select auth.uid()));
drop policy if exists "citizens view own reports" on public.content_reports;
create policy "citizens view own reports" on public.content_reports for select to authenticated using (reporter_id=(select auth.uid()));
grant select,insert on public.content_reports to authenticated;

create table if not exists private.area_admins(user_id uuid primary key references auth.users(id) on delete cascade,granted_at timestamptz not null default now());
alter table private.area_admins enable row level security;
revoke all on schema private from public,anon,authenticated;
revoke all on private.area_admins from public,anon,authenticated;

create or replace function public.is_area_admin()
returns boolean language sql stable security definer set search_path=''
as $function$ select exists(select 1 from private.area_admins a where a.user_id=(select auth.uid())); $function$;
revoke all on function public.is_area_admin() from public,anon;
grant execute on function public.is_area_admin() to authenticated;

create or replace function public.get_area_admin_overview()
returns jsonb language plpgsql stable security definer set search_path=''
as $function$
declare v_result jsonb;
begin
 if not public.is_area_admin() then raise exception 'Not authorized.'; end if;
 select jsonb_build_object(
  'citizens',(select count(*) from public.profiles),
  'posts',(select count(*) from public.posts),
  'replies',(select count(*) from public.replies),
  'messages',(select count(*) from public.direct_messages),
  'open_reports',(select count(*) from public.content_reports where status in ('open','under_review')),
  'recent_citizens',coalesce((select jsonb_agg(x) from (select p.id,p.username,p.display_name,p.area_class,p.created_at from public.profiles p order by p.created_at desc limit 8) x),'[]'::jsonb),
  'recent_posts',coalesce((select jsonb_agg(x) from (select po.id,po.content,po.created_at,pr.username,pr.display_name from public.posts po join public.profiles pr on pr.id=po.author_id order by po.created_at desc limit 8) x),'[]'::jsonb),
  'reports',coalesce((select jsonb_agg(x) from (select r.id,r.target_type,r.target_id,r.reason,r.details,r.status,r.created_at,p.username as reporter_username from public.content_reports r join public.profiles p on p.id=r.reporter_id where r.status in ('open','under_review') order by r.created_at desc limit 20) x),'[]'::jsonb)
 ) into v_result;
 return v_result;
end;
$function$;
revoke all on function public.get_area_admin_overview() from public,anon;
grant execute on function public.get_area_admin_overview() to authenticated;

create or replace function public.admin_update_content_report(p_report_id uuid,p_status text)
returns void language plpgsql security definer set search_path=''
as $function$
begin
 if not public.is_area_admin() then raise exception 'Not authorized.'; end if;
 if p_status not in ('under_review','resolved','dismissed') then raise exception 'Invalid report status.'; end if;
 update public.content_reports set status=p_status,reviewed_at=now(),reviewed_by=(select auth.uid()) where id=p_report_id;
 if not found then raise exception 'Report not found.'; end if;
end;
$function$;
revoke all on function public.admin_update_content_report(uuid,text) from public,anon;
grant execute on function public.admin_update_content_report(uuid,text) to authenticated;

do $publication$
begin
 if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='direct_messages') then
  alter publication supabase_realtime add table public.direct_messages;
 end if;
end
$publication$;
