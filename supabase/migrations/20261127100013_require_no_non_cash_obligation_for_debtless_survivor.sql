create or replace function private.record_debtless_survivor()
returns trigger language plpgsql security definer set search_path=''
as $function$
begin
 if old.status='inside' and new.status='released' and new.duty_due_ac=0 and new.duty_paid_ac=0 and new.noncash_obligation is null then
  insert into public.debtless_survivor_awards(citizen_id,earned_at) values(new.citizen_id,new.released_at) on conflict(citizen_id) do nothing;
 end if;
 return new;
end;$function$;
revoke all on function private.record_debtless_survivor() from public,anon,authenticated;