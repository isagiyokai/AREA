create or replace function public.agbero_enter_territory(p_territory_id uuid)
returns jsonb language plpgsql security definer set search_path=''
as $function$
declare v_user uuid:=auth.uid();v_territory public.agbero_territories;v_balance bigint:=0;v_area_share bigint:=0;v_owner_share bigint:=0;v_share_pct bigint:=30;v_paid bigint:=0;v_membership uuid;
begin
 if v_user is null then raise exception 'Sign in before entering a territory.';end if;
 if exists(select 1 from public.agbero_memberships where citizen_id=v_user and status='inside') then raise exception 'You are already inside a territory. The owner must release you before you can move on.';end if;
 select * into v_territory from public.agbero_territories where id=p_territory_id and active=true;
 if v_territory.id is null then raise exception 'This territory is unavailable.';end if;
 if v_territory.owner_id=v_user then raise exception 'You cannot be held inside your own territory.';end if;
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
create or replace function public.owner_set_agbero_obligation(p_membership_id uuid,p_obligation text)
returns void language plpgsql security definer set search_path=''
as $function$
begin
 if not exists(select 1 from public.agbero_memberships m join public.agbero_territories t on t.id=m.territory_id where m.id=p_membership_id and m.status='inside' and t.owner_id=auth.uid() and m.duty_paid_ac<m.duty_due_ac) then raise exception 'Only the territory owner can assign a non-cash obligation to an unpaid citizen.';end if;
 if p_obligation is null or length(btrim(p_obligation))<3 then raise exception 'Describe the non-cash obligation.';end if;
 update public.agbero_memberships set noncash_obligation=left(btrim(p_obligation),240),noncash_completed=false where id=p_membership_id;
end;$function$;
revoke all on function public.owner_set_agbero_obligation(uuid,text) from public,anon;grant execute on function public.owner_set_agbero_obligation(uuid,text) to authenticated;
create or replace function public.owner_complete_agbero_obligation(p_membership_id uuid)
returns void language plpgsql security definer set search_path=''
as $function$
begin
 if not exists(select 1 from public.agbero_memberships m join public.agbero_territories t on t.id=m.territory_id where m.id=p_membership_id and m.status='inside' and t.owner_id=auth.uid() and m.noncash_obligation is not null) then raise exception 'Only the territory owner can confirm an assigned obligation.';end if;
 update public.agbero_memberships set noncash_completed=true where id=p_membership_id;
end;$function$;
revoke all on function public.owner_complete_agbero_obligation(uuid) from public,anon;grant execute on function public.owner_complete_agbero_obligation(uuid) to authenticated;