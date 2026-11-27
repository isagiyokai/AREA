create or replace function private.assign_starter_connections()
returns trigger language plpgsql security definer set search_path=''
as $function$
declare v_classes jsonb;v_class text;v_target uuid;
begin
 if new.area_entry_tier is null then return new;end if;
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
update public.profiles set area_entry_tier=area_entry_tier where area_entry_tier is not null;