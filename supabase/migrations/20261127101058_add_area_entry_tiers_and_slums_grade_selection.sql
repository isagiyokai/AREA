create table if not exists public.area_entry_tiers(
 tier_key text primary key,area_class text not null check(area_class in('slums','lapo','nepo')),grade_title text not null,
 price_ngn bigint not null check(price_ngn>=0),starting_ac bigint not null default 0 check(starting_ac>=0),
 privileges jsonb not null default '{}'::jsonb,starter_connections jsonb not null default '[]'::jsonb,
 active boolean not null default true,sort_order smallint not null default 0
);
alter table public.area_entry_tiers enable row level security;
create policy "Citizens read active entry tiers" on public.area_entry_tiers for select to anon,authenticated using(active);
grant select on public.area_entry_tiers to anon,authenticated;
insert into public.area_entry_tiers(tier_key,area_class,grade_title,price_ngn,starting_ac,privileges,starter_connections,sort_order) values
('slums_street_material','slums','Street Material',0,0,'{}'::jsonb,'["nepo"]'::jsonb,1),
('lapo_starter','lapo','Lapo',1000,0,'{}'::jsonb,'["nepo"]'::jsonb,2),
('lapo_senior_man','lapo','Senior Man',2000,0,'{}'::jsonb,'["nepo"]'::jsonb,3),
('nepo_odogwu','nepo','Odogwu',5000,0,'{}'::jsonb,'[]'::jsonb,4)
on conflict(tier_key) do nothing;
alter table public.profiles add column if not exists area_grade text;
alter table public.profiles add column if not exists area_entry_tier text references public.area_entry_tiers(tier_key);
update public.profiles set area_grade='Street Material',area_entry_tier='slums_street_material' where area_class='slums' and area_entry_tier is null;
create or replace function public.select_free_slums_entry()
returns jsonb language plpgsql security definer set search_path=''
as $function$
declare v_user uuid:=auth.uid();
begin
 if v_user is null then raise exception 'Sign in to choose your AREA entry.';end if;
 if exists(select 1 from public.profiles where id=v_user and area_entry_tier is not null) then raise exception 'Your entry tier has already been selected.';end if;
 update public.profiles set area_class='slums',area_grade='Street Material',area_entry_tier='slums_street_material',updated_at=now() where id=v_user;
 return jsonb_build_object('area_class','slums','area_grade','Street Material','entry_tier','slums_street_material','price_ngn',0,'starting_ac',0);
end;$function$;
revoke all on function public.select_free_slums_entry() from public,anon;
grant execute on function public.select_free_slums_entry() to authenticated;