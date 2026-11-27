create table if not exists public.debtless_survivor_awards(citizen_id uuid primary key references auth.users(id) on delete cascade,earned_at timestamptz not null default now());
alter table public.debtless_survivor_awards enable row level security;
create policy "Citizens read debtless survivor awards" on public.debtless_survivor_awards for select to anon,authenticated using(true);
grant select on public.debtless_survivor_awards to anon,authenticated;
create or replace function private.record_debtless_survivor()
returns trigger language plpgsql security definer set search_path=''
as $function$
begin
 if old.status='inside' and new.status='released' and new.duty_due_ac=0 and new.duty_paid_ac=0 then
  insert into public.debtless_survivor_awards(citizen_id,earned_at) values(new.citizen_id,new.released_at) on conflict(citizen_id) do nothing;
 end if;
 return new;
end;$function$;
revoke all on function private.record_debtless_survivor() from public,anon,authenticated;
drop trigger if exists record_debtless_survivor on public.agbero_memberships;
create trigger record_debtless_survivor after update of status on public.agbero_memberships for each row execute function private.record_debtless_survivor();
create or replace view public.citizen_achievements with(security_invoker=true) as
with
first_posts as(select author_id user_id,min(created_at) earned_at from public.posts group by author_id),
first_replies as(select author_id user_id,min(created_at) earned_at from public.replies group by author_id),
conversation_starters as(select p.author_id user_id,min(p.created_at) earned_at from public.posts p join public.replies r on r.post_id=p.id and r.author_id<>p.author_id group by p.id,p.author_id having count(distinct r.author_id)>=3),
yard_debuts as(select x.user_id,min(ac.created_at) earned_at from public.argument_challenges ac cross join lateral(values(ac.challenger_id),(ac.challenged_id)) x(user_id) group by x.user_id),
yard_regulars as(select x.user_id,(select ac2.created_at from public.argument_challenges ac2 where ac2.challenger_id=x.user_id or ac2.challenged_id=x.user_id order by ac2.created_at asc offset 2 limit 1) earned_at from public.argument_challenges ac cross join lateral(values(ac.challenger_id,ac.challenged_id),(ac.challenged_id,ac.challenger_id)) x(user_id,opponent_id) where x.user_id is not null and x.opponent_id is not null and x.user_id<>x.opponent_id group by x.user_id having count(distinct ac.id)>=3 and count(distinct x.opponent_id)>=3),
connectors as(select p.id user_id,greatest((select f.created_at from public.follows f where f.followed_id=p.id order by f.created_at asc offset 4 limit 1),(select f.created_at from public.follows f where f.follower_id=p.id order by f.created_at asc offset 4 limit 1)) earned_at from public.profiles p where(select count(*) from public.follows f where f.followed_id=p.id)>=5 and(select count(*) from public.follows f where f.follower_id=p.id)>=5),
educated as(select p.author_id user_id,min(r.created_at) earned_at from public.post_reactions r join public.posts p on p.id=r.post_id where r.reaction_type='educated' and r.user_id<>p.author_id group by p.author_id having count(distinct r.user_id)>=5 and count(distinct r.post_id)>=3),
educated_agberos as(select p.author_id user_id,min(r.created_at) earned_at from public.post_reactions r join public.posts p on p.id=r.post_id where r.reaction_type='educated' and r.user_id<>p.author_id and exists(select 1 from public.argument_challenges ac where ac.post_id=p.id) group by p.author_id having count(distinct r.user_id)>=5 and count(distinct r.post_id)>=3),
debtless_survivors as(select citizen_id user_id,min(earned_at) earned_at from public.debtless_survivor_awards group by citizen_id)
select user_id,'first-footprint'::text achievement_key,'First Footprint'::text title,'Your first post on the street.'::text description,'STREET'::text category,earned_at from first_posts
union all select user_id,'first-exchange','First Exchange','You entered the conversation with your first reply.','STREET',earned_at from first_replies
union all select user_id,'conversation-starter','Conversation Starter','One of your posts drew replies from at least three different citizens.','STREET',earned_at from conversation_starters
union all select user_id,'yard-debut','Yard Debut','You stepped into your first Gbas Gbos callout.','GBAS GBOS',earned_at from yard_debuts
union all select user_id,'yard-regular','Yard Regular','You faced at least three different citizens across three or more callouts.','GBAS GBOS',earned_at from yard_regulars
union all select user_id,'community-connector','Community Connector','You built at least five incoming and five outgoing citizen connections.','COMMUNITY',earned_at from connectors
union all select user_id,'educated','Educated','At least five different citizens recognised your contributions across three posts.','RECOGNITION',earned_at from educated
union all select user_id,'educated-agbero','Educated Agbero','Your Gbas Gbos arguments earned recognition from at least five different citizens across three callout threads.','GBAS GBOS',earned_at from educated_agberos
union all select user_id,'debtless-survivor','Debtless Survivor','You left an Agbero territory without being billed.','TERRITORIES',earned_at from debtless_survivors;
grant select on public.citizen_achievements to anon,authenticated;