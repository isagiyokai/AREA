create table public.area_tags (
  id uuid primary key default gen_random_uuid(),
  tag text not null check (tag ~ '^[a-z0-9_]{2,32}$'),
  post_id uuid references public.posts(id) on delete cascade,
  reply_id uuid references public.replies(id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint area_tags_one_source check ((post_id is not null)::integer + (reply_id is not null)::integer = 1)
);
create unique index area_tags_post_unique on public.area_tags(post_id, tag) where post_id is not null;
create unique index area_tags_reply_unique on public.area_tags(reply_id, tag) where reply_id is not null;
create index area_tags_tag_created_idx on public.area_tags(tag, created_at desc);
alter table public.area_tags enable row level security;
create policy "Anyone can read AREA tags" on public.area_tags for select to anon, authenticated using (true);
grant select on public.area_tags to anon, authenticated;

alter table public.notifications drop constraint notifications_notification_type_check;
alter table public.notifications add constraint notifications_notification_type_check
  check (notification_type = any (array[
    'argument_invitation','argument_response','argument_escalation','escalation_response',
    'post_reply','quote_post','mention_post','mention_reply'
  ]::text[]));

create or replace function private.area_sync_tags()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare v_match text[];
begin
  if tg_table_name = 'posts' then
    delete from public.area_tags where post_id = new.id;
    for v_match in select m.parts from regexp_matches(new.content, '(^|[^[:alnum:]_])#([a-z0-9_]{2,32})([^a-z0-9_]|$)', 'gi') as m(parts)
    loop
      insert into public.area_tags(tag, post_id, created_at) values (lower(v_match[2]), new.id, new.created_at)
      on conflict (post_id, tag) where post_id is not null do nothing;
    end loop;
  else
    delete from public.area_tags where reply_id = new.id;
    for v_match in select m.parts from regexp_matches(new.content, '(^|[^[:alnum:]_])#([a-z0-9_]{2,32})([^a-z0-9_]|$)', 'gi') as m(parts)
    loop
      insert into public.area_tags(tag, reply_id, created_at) values (lower(v_match[2]), new.id, new.created_at)
      on conflict (reply_id, tag) where reply_id is not null do nothing;
    end loop;
  end if;
  return new;
end;
$$;

create or replace function private.area_notify_mentions()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare v_match text[]; v_post_id uuid; v_actor_username text; v_target record;
begin
  if tg_table_name = 'posts' then v_post_id := new.id; else v_post_id := new.post_id; end if;
  select p.username into v_actor_username from public.profiles p where p.id = new.author_id;
  for v_match in
    select distinct m.parts from regexp_matches(new.content, '(^|[^[:alnum:]_.+%-])@([a-z0-9_]{3,24})([^a-z0-9_]|$)', 'gi') as m(parts)
  loop
    select p.id, p.username into v_target from public.profiles p where p.username = lower(v_match[2]);
    if found and v_target.id <> new.author_id then
      insert into public.notifications(recipient_id, actor_id, notification_type, message, post_id)
      values (v_target.id, new.author_id,
        case when tg_table_name = 'posts' then 'mention_post' else 'mention_reply' end,
        left('@' || coalesce(v_actor_username, 'citizen') ||
          case when tg_table_name = 'posts' then ' mentioned you in a post' else ' mentioned you in a reply' end, 240),
        v_post_id);
    end if;
  end loop;
  return new;
end;
$$;
revoke all on function private.area_sync_tags() from public, anon, authenticated;
revoke all on function private.area_notify_mentions() from public, anon, authenticated;
create trigger area_posts_sync_tags after insert or update of content on public.posts for each row execute function private.area_sync_tags();
create trigger area_replies_sync_tags after insert or update of content on public.replies for each row execute function private.area_sync_tags();
create trigger area_posts_notify_mentions after insert on public.posts for each row execute function private.area_notify_mentions();
create trigger area_replies_notify_mentions after insert on public.replies for each row execute function private.area_notify_mentions();

create or replace view public.trending_tags with (security_invoker = true) as
select tag, count(*)::bigint as usage_count, max(created_at) as latest_activity
from public.area_tags where created_at >= now() - interval '24 hours'
group by tag having count(*) >= 2
order by usage_count desc, latest_activity desc limit 12;
grant select on public.trending_tags to anon, authenticated;