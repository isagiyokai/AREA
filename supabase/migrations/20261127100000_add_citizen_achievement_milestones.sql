create or replace view public.citizen_achievements
with (security_invoker = true)
as
with
first_posts as (
  select author_id as user_id, min(created_at) as earned_at from public.posts group by author_id
),
first_replies as (
  select author_id as user_id, min(created_at) as earned_at from public.replies group by author_id
),
conversation_starters as (
  select p.author_id as user_id, min(p.created_at) as earned_at
  from public.posts p
  join public.replies r on r.post_id = p.id and r.author_id <> p.author_id
  group by p.id, p.author_id
  having count(distinct r.author_id) >= 3
),
yard_debuts as (
  select participant.user_id, min(ac.created_at) as earned_at
  from public.argument_challenges ac
  cross join lateral (values (ac.challenger_id), (ac.challenged_id)) as participant(user_id)
  where participant.user_id is not null
  group by participant.user_id
),
yard_regulars as (
  select participant.user_id, min(ac.created_at) as earned_at
  from public.argument_challenges ac
  cross join lateral (values (ac.challenger_id, ac.challenged_id), (ac.challenged_id, ac.challenger_id)) as participant(user_id, opponent_id)
  where participant.user_id is not null and participant.opponent_id is not null and participant.user_id <> participant.opponent_id
  group by participant.user_id
  having count(distinct ac.id) >= 3 and count(distinct participant.opponent_id) >= 3
),
connectors as (
  select p.id as user_id, now() as earned_at
  from public.profiles p
  where (select count(*) from public.follows f where f.followed_id = p.id) >= 5
    and (select count(*) from public.follows f where f.follower_id = p.id) >= 5
)
select user_id, 'first-footprint'::text as achievement_key, 'First Footprint'::text as title, 'Your first post on the street.'::text as description, 'STREET'::text as category, earned_at from first_posts
union all
select user_id, 'first-exchange', 'First Exchange', 'You entered the conversation with your first reply.', 'STREET', earned_at from first_replies
union all
select user_id, 'conversation-starter', 'Conversation Starter', 'One of your posts drew replies from at least three different citizens.', 'STREET', earned_at from conversation_starters
union all
select user_id, 'yard-debut', 'Yard Debut', 'You stepped into your first Gbas Gbos callout.', 'GBAS GBOS', earned_at from yard_debuts
union all
select user_id, 'yard-regular', 'Yard Regular', 'You faced at least three different citizens across three or more callouts.', 'GBAS GBOS', earned_at from yard_regulars
union all
select user_id, 'community-connector', 'Community Connector', 'You built at least five incoming and five outgoing citizen connections.', 'COMMUNITY', earned_at from connectors;
grant select on public.citizen_achievements to anon, authenticated;