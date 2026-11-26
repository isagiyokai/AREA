create or replace view public.citizen_standing
with (security_invoker = true)
as
with post_stats as (
  select author_id, count(*)::integer as posts
  from public.posts
  group by author_id
),
reply_stats as (
  select author_id, count(*)::integer as replies
  from public.replies
  group by author_id
),
reply_received as (
  select p.author_id, count(r.id)::integer as replies_received
  from public.posts p
  join public.replies r on r.post_id = p.id
  group by p.author_id
),
follower_stats as (
  select followed_id, count(*)::integer as followers
  from public.follows
  group by followed_id
),
scored as (
  select
    p.id as user_id,
    p.username,
    p.display_name,
    p.area_class,
    p.created_at,
    coalesce(ps.posts, 0) as posts,
    coalesce(rs.replies, 0) as replies,
    coalesce(rr.replies_received, 0) as replies_received,
    coalesce(fs.followers, 0) as followers,
    (
      coalesce(ps.posts, 0)
      + coalesce(rs.replies, 0) * 2
      + coalesce(rr.replies_received, 0) * 2
      + coalesce(fs.followers, 0) * 3
    )::integer as standing_points
  from public.profiles p
  left join post_stats ps on ps.author_id = p.id
  left join reply_stats rs on rs.author_id = p.id
  left join reply_received rr on rr.author_id = p.id
  left join follower_stats fs on fs.followed_id = p.id
)
select
  user_id, username, display_name, area_class, created_at,
  posts, replies, replies_received, followers, standing_points,
  case
    when standing_points >= 100 then 'Area fixture'
    when standing_points >= 50 then 'Yard regular'
    when standing_points >= 20 then 'Street regular'
    when standing_points >= 5 then 'Known voice'
    else 'New voice'
  end as standing_title,
  rank() over (order by standing_points desc) as standing_rank
from scored;

grant select on public.citizen_standing to anon, authenticated;