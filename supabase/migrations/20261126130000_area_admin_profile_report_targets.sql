create or replace function public.get_area_admin_overview()
returns jsonb language plpgsql stable security definer set search_path=''
as $function$
declare v_result jsonb;
begin
 if not public.is_area_admin() then raise exception 'Not authorized.'; end if;
 select jsonb_build_object(
  'citizens',(select count(*) from public.profiles),
  'posts',(select count(*) from public.posts),
  'replies',(select count(*) from public.replies),
  'messages',(select count(*) from public.direct_messages),
  'open_reports',(select count(*) from public.content_reports where status in ('open','under_review')),
  'recent_citizens',coalesce((select jsonb_agg(x) from (select p.id,p.username,p.display_name,p.area_class,p.created_at from public.profiles p order by p.created_at desc limit 8) x),'[]'::jsonb),
  'recent_posts',coalesce((select jsonb_agg(x) from (select po.id,po.content,po.created_at,pr.username,pr.display_name from public.posts po join public.profiles pr on pr.id=po.author_id order by po.created_at desc limit 8) x),'[]'::jsonb),
  'reports',coalesce((select jsonb_agg(x) from (
    select r.id,r.target_type,r.target_id,r.reason,r.details,r.status,r.created_at,
      reporter.username as reporter_username,target.username as target_username
    from public.content_reports r
    join public.profiles reporter on reporter.id=r.reporter_id
    left join public.profiles target on r.target_type='profile' and target.id=r.target_id
    where r.status in ('open','under_review') order by r.created_at desc limit 20
  ) x),'[]'::jsonb)
 ) into v_result;
 return v_result;
end;
$function$;
revoke all on function public.get_area_admin_overview() from public,anon;
grant execute on function public.get_area_admin_overview() to authenticated;
