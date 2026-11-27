update public.area_entry_tiers set grade_title='Street Rookie' where tier_key='slums_street_material';
create or replace function public.select_free_slums_entry()
returns jsonb language plpgsql security definer set search_path=''
as $function$
declare v_user uuid:=auth.uid();v_grade text;
begin
 if v_user is null then raise exception 'Sign in to choose your AREA entry.';end if;
 if exists(select 1 from public.profiles where id=v_user and area_entry_tier is not null) then raise exception 'Your entry tier has already been selected.';end if;
 select grade_title into v_grade from public.area_entry_tiers where tier_key='slums_street_material';
 update public.profiles set area_class='slums',area_grade=v_grade,area_entry_tier='slums_street_material',updated_at=now() where id=v_user;
 return jsonb_build_object('area_class','slums','area_grade',v_grade,'entry_tier','slums_street_material','price_ngn',0,'starting_ac',0);
end;$function$;
revoke all on function public.select_free_slums_entry() from public,anon;grant execute on function public.select_free_slums_entry() to authenticated;
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
   else
    insert into public.citizen_introductions(requester_id,introduced_id,target_class,status,introduced_at) values(new.id,v_target,v_class,'introduced',now());
    update public.profiles set area_grade=case when new.area_class='slums' then 'Street Material' when new.area_class='lapo' and new.area_grade='Lapo' then 'Senior Man' else new.area_grade end where id=new.id;
   end if;
  end if;
 end loop;
 return new;
end;$function$;
revoke all on function private.assign_starter_connections() from public,anon,authenticated;
create or replace function private.assign_pending_starter_introduction()
returns trigger language plpgsql security definer set search_path=''
as $function$
declare v_intro uuid;v_requester uuid;v_requester_class text;v_grade text;
begin
 if new.area_class is distinct from old.area_class and new.area_class is not null then
  if not exists(select 1 from public.citizen_introductions where introduced_id=new.id and status='introduced') then
   select id,requester_id into v_intro,v_requester from public.citizen_introductions where target_class=new.area_class and status='pending' order by created_at asc for update skip locked limit 1;
   if v_intro is not null then
    update public.citizen_introductions set introduced_id=new.id,status='introduced',introduced_at=now() where id=v_intro;
    select area_class,area_grade into v_requester_class,v_grade from public.profiles where id=v_requester;
    update public.profiles set area_grade=case when v_requester_class='slums' then 'Street Material' when v_requester_class='lapo' and v_grade='Lapo' then 'Senior Man' else v_grade end where id=v_requester;
   end if;
  end if;
 end if;
 return new;
end;$function$;
revoke all on function private.assign_pending_starter_introduction() from public,anon,authenticated;
update public.profiles set area_grade='Street Rookie' where area_entry_tier='slums_street_material';
update public.profiles p set area_grade=case when p.area_class='slums' then 'Street Material' when p.area_class='lapo' and p.area_grade='Lapo' then 'Senior Man' else p.area_grade end
where exists(select 1 from public.citizen_introductions ci where ci.requester_id=p.id and ci.target_class='nepo' and ci.status='introduced');