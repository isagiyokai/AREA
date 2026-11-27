create table if not exists public.citizen_introductions(
 id uuid primary key default gen_random_uuid(),requester_id uuid not null references auth.users(id) on delete cascade,
 introduced_id uuid references auth.users(id) on delete set null,target_class text not null check(target_class in('slums','lapo','nepo')),
 status text not null default 'pending' check(status in('pending','introduced')),created_at timestamptz not null default now(),introduced_at timestamptz
);
create unique index if not exists citizen_one_active_starter_intro on public.citizen_introductions(requester_id) where status in('pending','introduced');
create index if not exists citizen_introductions_target_idx on public.citizen_introductions(target_class,status,created_at);
alter table public.citizen_introductions enable row level security;
create policy "Citizens read their starter introductions" on public.citizen_introductions for select to authenticated using(requester_id=(select auth.uid()) or introduced_id=(select auth.uid()));
grant select on public.citizen_introductions to authenticated;
create or replace function private.assign_starter_connections()
returns trigger language plpgsql security definer set search_path=''
as $function$
declare v_classes jsonb;v_class text;v_target uuid;
begin
 if new.area_entry_tier is null or new.area_entry_tier is not distinct from old.area_entry_tier then return new;end if;
 select starter_connections into v_classes from public.area_entry_tiers where tier_key=new.area_entry_tier;
 for v_class in select jsonb_array_elements_text(coalesce(v_classes,'[]'::jsonb)) loop
  if not exists(select 1 from public.citizen_introductions where requester_id=new.id and status in('pending','introduced')) then
   select p.id into v_target from public.profiles p where p.area_class=v_class and p.id<>new.id
    and not exists(select 1 from public.citizen_introductions ci where ci.introduced_id=p.id and ci.status='introduced')
   order by p.created_at asc limit 1;
   if v_target is null then insert into public.citizen_introductions(requester_id,target_class,status) values(new.id,v_class,'pending');
   else insert into public.citizen_introductions(requester_id,introduced_id,target_class,status,introduced_at) values(new.id,v_target,v_class,'introduced',now());end if;
  end if;
 end loop;
 return new;
end;$function$;
revoke all on function private.assign_starter_connections() from public,anon,authenticated;
create trigger assign_starter_connections after update of area_entry_tier on public.profiles for each row execute function private.assign_starter_connections();
create or replace function private.assign_pending_starter_introduction()
returns trigger language plpgsql security definer set search_path=''
as $function$
declare v_intro uuid;
begin
 if new.area_class is distinct from old.area_class and new.area_class is not null then
  if not exists(select 1 from public.citizen_introductions where introduced_id=new.id and status='introduced') then
   select id into v_intro from public.citizen_introductions where target_class=new.area_class and status='pending' order by created_at asc for update skip locked limit 1;
   if v_intro is not null then update public.citizen_introductions set introduced_id=new.id,status='introduced',introduced_at=now() where id=v_intro;end if;
  end if;
 end if;
 return new;
end;$function$;
revoke all on function private.assign_pending_starter_introduction() from public,anon,authenticated;
create trigger assign_pending_starter_introduction after update of area_class on public.profiles for each row execute function private.assign_pending_starter_introduction();