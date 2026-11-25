create or replace function private.area_sync_tags()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare v_match text[];
begin
  if tg_table_name = 'posts' then
    delete from public.area_tags where post_id = new.id;
    for v_match in select m.parts from regexp_matches(new.content, '(^|[^[:alnum:]_#])#([a-z0-9_]{2,32})([^a-z0-9_]|$)', 'gi') as m(parts)
    loop
      insert into public.area_tags(tag, post_id, created_at) values (lower(v_match[2]), new.id, new.created_at)
      on conflict (post_id, tag) where post_id is not null do nothing;
    end loop;
  else
    delete from public.area_tags where reply_id = new.id;
    for v_match in select m.parts from regexp_matches(new.content, '(^|[^[:alnum:]_#])#([a-z0-9_]{2,32})([^a-z0-9_]|$)', 'gi') as m(parts)
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
declare v_username text; v_actor_username text; v_target_id uuid; v_post_id uuid;
begin
  if tg_table_name = 'posts' then v_post_id := new.id; else v_post_id := new.post_id; end if;
  select p.username into v_actor_username from public.profiles p where p.id = new.author_id;
  for v_username in
    select distinct lower(m.parts[2])
    from regexp_matches(new.content, '(^|[^[:alnum:]_.+%-])@([a-z0-9_]{3,24})([^a-z0-9_]|$)', 'gi') as m(parts)
  loop
    select p.id into v_target_id from public.profiles p where p.username = v_username;
    if found and v_target_id <> new.author_id then
      insert into public.notifications(recipient_id, actor_id, notification_type, message, post_id)
      values (v_target_id, new.author_id,
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