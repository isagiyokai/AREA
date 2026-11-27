create table if not exists public.agbero_territories(
 id uuid primary key default gen_random_uuid(),owner_id uuid not null references public.profiles(id) on delete restrict,
 name text not null check(char_length(btrim(name)) between 3 and 60),description text not null default '',
 stamp_duty_ac bigint not null default 0 check(stamp_duty_ac between 0 and 1000000000),active boolean not null default true,created_at timestamptz not null default now()
);
create index if not exists agbero_territories_owner_idx on public.agbero_territories(owner_id);
create table if not exists public.agbero_memberships(
 id uuid primary key default gen_random_uuid(),territory_id uuid not null references public.agbero_territories(id) on delete restrict,
 citizen_id uuid not null references auth.users(id) on delete cascade,status text not null default 'inside' check(status in('inside','released')),
 entered_at timestamptz not null default now(),released_at timestamptz,duty_due_ac bigint not null default 0 check(duty_due_ac>=0),
 duty_paid_ac bigint not null default 0 check(duty_paid_ac>=0 and duty_paid_ac<=duty_due_ac),noncash_obligation text,noncash_completed boolean not null default false,
 check((status='inside' and released_at is null) or(status='released' and released_at is not null))
);
create unique index if not exists agbero_one_active_membership_per_citizen on public.agbero_memberships(citizen_id) where status='inside';
create index if not exists agbero_memberships_territory_status_idx on public.agbero_memberships(territory_id,status,entered_at desc);
alter table public.agbero_territories enable row level security;alter table public.agbero_memberships enable row level security;
create policy "Citizens read active Agbero territories" on public.agbero_territories for select to anon,authenticated using(active);
create policy "Citizens and territory owners read memberships" on public.agbero_memberships for select to authenticated using(citizen_id=(select auth.uid()) or exists(select 1 from public.agbero_territories t where t.id=territory_id and t.owner_id=(select auth.uid())));
grant select on public.agbero_territories,public.agbero_memberships to anon,authenticated;
create or replace function public.admin_create_agbero_territory(p_owner_username text,p_name text,p_description text,p_stamp_duty_ac bigint)
returns uuid language plpgsql security definer set search_path=''
as $function$
declare v_owner uuid;v_id uuid;
begin
 if not public.is_area_admin() then raise exception 'Owner access required.';end if;
 if p_stamp_duty_ac is null or p_stamp_duty_ac<0 or p_stamp_duty_ac>1000000000 then raise exception 'Invalid stamp duty.';end if;
 select id into v_owner from public.profiles where username=lower(btrim(p_owner_username));
 if v_owner is null then raise exception 'Territory owner not found.';end if;
 insert into public.agbero_territories(owner_id,name,description,stamp_duty_ac) values(v_owner,left(btrim(p_name),60),left(btrim(coalesce(p_description,'')),500),p_stamp_duty_ac) returning id into v_id;
 return v_id;
end;$function$;
revoke all on function public.admin_create_agbero_territory(text,text,text,bigint) from public,anon;grant execute on function public.admin_create_agbero_territory(text,text,text,bigint) to authenticated;
create or replace function public.agbero_enter_territory(p_territory_id uuid) returns jsonb language plpgsql security definer set search_path='' as $function$
declare v_user uuid:=auth.uid();v_territory public.agbero_territories;v_balance bigint:=0;v_area_share bigint:=0;v_owner_share bigint:=0;v_share_pct bigint:=30;v_paid bigint:=0;v_membership uuid;
begin
 if v_user is null then raise exception 'Sign in before entering a territory.';end if;
 if exists(select 1 from public.agbero_memberships where citizen_id=v_user and status='inside') then raise exception 'You are already inside a territory. The owner must release you before you can move on.';end if;
 select * into v_territory from public.agbero_territories where id=p_territory_id and active=true;
 if v_territory.id is null then raise exception 'This territory is unavailable.';end if;
 select setting_value into v_share_pct from public.area_economy_settings where setting_key='agbero_area_share_percent';v_share_pct:=coalesce(v_share_pct,30);
 if v_territory.stamp_duty_ac>0 then
  insert into private.wallet_accounts(user_id,balance_ac) values(v_user,0) on conflict(user_id) do nothing;
  perform 1 from private.wallet_accounts where user_id=v_user for update;
  select balance_ac into v_balance from private.wallet_accounts where user_id=v_user;
  if v_balance>=v_territory.stamp_duty_ac then
   v_paid:=v_territory.stamp_duty_ac;v_area_share:=floor(v_paid*v_share_pct/100.0)::bigint;v_owner_share:=v_paid-v_area_share;
   update private.wallet_accounts set balance_ac=balance_ac-v_paid,updated_at=now() where user_id=v_user;
   if v_owner_share>0 then
    insert into private.wallet_accounts(user_id,balance_ac) values(v_territory.owner_id,0) on conflict(user_id) do nothing;
    update private.wallet_accounts set balance_ac=balance_ac+v_owner_share,updated_at=now() where user_id=v_territory.owner_id;
    insert into private.ac_ledger(from_user_id,to_user_id,amount_ac,transaction_type,note) values(v_user,v_territory.owner_id,v_owner_share,'fee','Agbero stamp duty: '||v_territory.name);
   end if;
   if v_area_share>0 then insert into private.ac_ledger(from_user_id,amount_ac,transaction_type,note) values(v_user,v_area_share,'fee','AREA share of Agbero stamp duty: '||v_territory.name);end if;
  end if;
 end if;
 insert into public.agbero_memberships(territory_id,citizen_id,duty_due_ac,duty_paid_ac) values(p_territory_id,v_user,v_territory.stamp_duty_ac,v_paid) returning id into v_membership;
 return jsonb_build_object('membership_id',v_membership,'territory',v_territory.name,'duty_due_ac',v_territory.stamp_duty_ac,'duty_paid_ac',v_paid,'balance_ac',v_balance-v_paid);
end;$function$;
revoke all on function public.agbero_enter_territory(uuid) from public,anon;grant execute on function public.agbero_enter_territory(uuid) to authenticated;
create or replace function public.pay_agbero_duty(p_membership_id uuid) returns jsonb language plpgsql security definer set search_path='' as $function$
declare v_user uuid:=auth.uid();v_membership public.agbero_memberships;v_territory public.agbero_territories;v_due bigint;v_balance bigint;v_area_share bigint;v_owner_share bigint;v_share_pct bigint:=30;
begin
 if v_user is null then raise exception 'Sign in to pay your stamp duty.';end if;
 select * into v_membership from public.agbero_memberships where id=p_membership_id and citizen_id=v_user and status='inside' for update;
 if v_membership.id is null then raise exception 'This territory membership is no longer active.';end if;
 v_due:=v_membership.duty_due_ac-v_membership.duty_paid_ac;if v_due<=0 then raise exception 'Your stamp duty is already settled.';end if;
 select * into v_territory from public.agbero_territories where id=v_membership.territory_id;
 select setting_value into v_share_pct from public.area_economy_settings where setting_key='agbero_area_share_percent';v_share_pct:=coalesce(v_share_pct,30);
 insert into private.wallet_accounts(user_id,balance_ac) values(v_user,0) on conflict(user_id) do nothing;
 perform 1 from private.wallet_accounts where user_id=v_user for update;
 select balance_ac into v_balance from private.wallet_accounts where user_id=v_user;
 if v_balance<v_due then raise exception 'You need % AC to settle the remaining duty. Your wallet has % AC.',v_due,v_balance;end if;
 v_area_share:=floor(v_due*v_share_pct/100.0)::bigint;v_owner_share:=v_due-v_area_share;
 update private.wallet_accounts set balance_ac=balance_ac-v_due,updated_at=now() where user_id=v_user;
 if v_owner_share>0 then
  insert into private.wallet_accounts(user_id,balance_ac) values(v_territory.owner_id,0) on conflict(user_id) do nothing;
  update private.wallet_accounts set balance_ac=balance_ac+v_owner_share,updated_at=now() where user_id=v_territory.owner_id;
  insert into private.ac_ledger(from_user_id,to_user_id,amount_ac,transaction_type,note) values(v_user,v_territory.owner_id,v_owner_share,'fee','Agbero stamp duty: '||v_territory.name);
 end if;
 if v_area_share>0 then insert into private.ac_ledger(from_user_id,amount_ac,transaction_type,note) values(v_user,v_area_share,'fee','AREA share of Agbero stamp duty: '||v_territory.name);end if;
 update public.agbero_memberships set duty_paid_ac=duty_due_ac where id=p_membership_id;
 return jsonb_build_object('paid_ac',v_due,'balance_ac',v_balance-v_due);
end;$function$;
revoke all on function public.pay_agbero_duty(uuid) from public,anon;grant execute on function public.pay_agbero_duty(uuid) to authenticated;
create or replace function public.owner_set_agbero_obligation(p_membership_id uuid,p_obligation text) returns void language plpgsql security definer set search_path='' as $function$
begin
 if not exists(select 1 from public.agbero_memberships m join public.agbero_territories t on t.id=m.territory_id where m.id=p_membership_id and m.status='inside' and t.owner_id=auth.uid()) then raise exception 'Only the territory owner can set this obligation.';end if;
 if p_obligation is null or length(btrim(p_obligation))<3 then raise exception 'Describe the non-cash obligation.';end if;
 update public.agbero_memberships set noncash_obligation=left(btrim(p_obligation),240),noncash_completed=false where id=p_membership_id;
end;$function$;
revoke all on function public.owner_set_agbero_obligation(uuid,text) from public,anon;grant execute on function public.owner_set_agbero_obligation(uuid,text) to authenticated;
create or replace function public.owner_complete_agbero_obligation(p_membership_id uuid) returns void language plpgsql security definer set search_path='' as $function$
begin
 if not exists(select 1 from public.agbero_memberships m join public.agbero_territories t on t.id=m.territory_id where m.id=p_membership_id and m.status='inside' and t.owner_id=auth.uid()) then raise exception 'Only the territory owner can confirm this obligation.';end if;
 update public.agbero_memberships set noncash_completed=true where id=p_membership_id;
end;$function$;
revoke all on function public.owner_complete_agbero_obligation(uuid) from public,anon;grant execute on function public.owner_complete_agbero_obligation(uuid) to authenticated;
create or replace function public.owner_release_agbero_citizen(p_membership_id uuid) returns void language plpgsql security definer set search_path='' as $function$
begin
 if not exists(select 1 from public.agbero_memberships m join public.agbero_territories t on t.id=m.territory_id where m.id=p_membership_id and m.status='inside' and t.owner_id=auth.uid()) then raise exception 'Only the territory owner can release this citizen.';end if;
 update public.agbero_memberships set status='released',released_at=now() where id=p_membership_id;
end;$function$;
revoke all on function public.owner_release_agbero_citizen(uuid) from public,anon;grant execute on function public.owner_release_agbero_citizen(uuid) to authenticated;