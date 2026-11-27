create table if not exists public.area_market_items(
 id uuid primary key default gen_random_uuid(),slug text not null unique,name text not null,description text not null,
 category text not null check(category in('profile_frame','profile_stamp','nameplate','profile_backdrop')),
 price_ac bigint not null check(price_ac>=0),active boolean not null default true,created_at timestamptz not null default now()
);
create table if not exists public.citizen_inventory(
 id uuid primary key default gen_random_uuid(),user_id uuid not null references auth.users(id) on delete cascade,
 item_id uuid not null references public.area_market_items(id) on delete restrict,equipped boolean not null default false,
 acquired_at timestamptz not null default now(),unique(user_id,item_id)
);
create index if not exists citizen_inventory_user_idx on public.citizen_inventory(user_id);
create index if not exists citizen_inventory_item_idx on public.citizen_inventory(item_id);
alter table public.area_market_items enable row level security;alter table public.citizen_inventory enable row level security;
create policy "Citizens read active market items" on public.area_market_items for select to anon,authenticated using(active);
create policy "Citizens read their inventory and equipped cosmetics" on public.citizen_inventory for select to anon,authenticated using(equipped=true or user_id=(select auth.uid()));
grant select on public.area_market_items,public.citizen_inventory to anon,authenticated;
insert into public.area_market_items(slug,name,description,category,price_ac) values
('street-frame','Street Frame','A bold frame for your citizen profile.','profile_frame',25000),
('yard-mark','Yard Mark','A small mark that shows you have spent time in the yard.','profile_stamp',40000),
('ink-nameplate','Ink Nameplate','Give your display name a distinct accent.','nameplate',60000),
('after-hours','After Hours','A darker profile backdrop for late-night citizens.','profile_backdrop',90000)
on conflict(slug) do nothing;
create or replace function public.purchase_market_item(p_item_id uuid) returns jsonb language plpgsql security definer set search_path='' as $function$
declare v_user uuid:=auth.uid();v_item public.area_market_items;v_balance bigint;v_next bigint;v_inventory_id uuid;
begin
 if v_user is null then raise exception 'Sign in to shop in AREA Market.';end if;
 select * into v_item from public.area_market_items where id=p_item_id and active=true;
 if v_item.id is null then raise exception 'This item is not available.';end if;
 if exists(select 1 from public.citizen_inventory where user_id=v_user and item_id=p_item_id) then raise exception 'You already own this item.';end if;
 insert into private.wallet_accounts(user_id,balance_ac) values(v_user,0) on conflict(user_id) do nothing;
 perform 1 from private.wallet_accounts where user_id=v_user for update;
 select balance_ac into v_balance from private.wallet_accounts where user_id=v_user;
 if v_balance<v_item.price_ac then raise exception 'This item costs % AC. Your wallet has % AC.',v_item.price_ac,v_balance;end if;
 v_next:=v_balance-v_item.price_ac;
 update private.wallet_accounts set balance_ac=v_next,updated_at=now() where user_id=v_user;
 insert into public.citizen_inventory(user_id,item_id) values(v_user,p_item_id) returning id into v_inventory_id;
 insert into private.ac_ledger(from_user_id,amount_ac,transaction_type,note) values(v_user,v_item.price_ac,'purchase','AREA Market: '||v_item.name);
 return jsonb_build_object('inventory_id',v_inventory_id,'item_name',v_item.name,'amount_ac',v_item.price_ac,'balance_ac',v_next);
end;$function$;
revoke all on function public.purchase_market_item(uuid) from public,anon;grant execute on function public.purchase_market_item(uuid) to authenticated;
create or replace function public.equip_market_item(p_item_id uuid) returns void language plpgsql security definer set search_path='' as $function$
declare v_user uuid:=auth.uid();v_item public.area_market_items;
begin
 if v_user is null then raise exception 'Sign in to equip an item.';end if;
 select m.* into v_item from public.area_market_items m join public.citizen_inventory i on i.item_id=m.id where i.user_id=v_user and m.id=p_item_id;
 if v_item.id is null then raise exception 'You do not own this item.';end if;
 update public.citizen_inventory i set equipped=false from public.area_market_items m where i.user_id=v_user and i.item_id=m.id and m.category=v_item.category;
 update public.citizen_inventory set equipped=true where user_id=v_user and item_id=p_item_id;
end;$function$;
revoke all on function public.equip_market_item(uuid) from public,anon;grant execute on function public.equip_market_item(uuid) to authenticated;