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