drop policy if exists "Citizens create own posts" on public.posts;
create policy "Citizens create own posts" on public.posts for insert to authenticated
with check((select auth.uid())=author_id and not exists(select 1 from public.citizen_penances cp where cp.user_id=(select auth.uid()) and cp.ends_at>now()) and (not exists(select 1 from public.agbero_territories t where t.active=true) or exists(select 1 from public.agbero_memberships m where m.citizen_id=(select auth.uid()) and m.status='inside')));
drop policy if exists "Citizens create own replies" on public.replies;
create policy "Citizens create own replies" on public.replies for insert to authenticated
with check((select auth.uid())=author_id and not exists(select 1 from public.citizen_penances cp where cp.user_id=(select auth.uid()) and cp.ends_at>now()) and (not exists(select 1 from public.agbero_territories t where t.active=true) or exists(select 1 from public.agbero_memberships m where m.citizen_id=(select auth.uid()) and m.status='inside')));
create or replace function public.create_argument_challenge(p_post_id uuid,p_opponent_id uuid,p_intensity smallint)
returns public.argument_challenges language plpgsql security definer set search_path=''
as $function$
declare v_user_id uuid:=auth.uid();v_result public.argument_challenges;v_post_author uuid;v_recent_count integer;
begin
 if v_user_id is null then raise exception 'You must sign in to make a public callout.';end if;
 if exists(select 1 from public.citizen_penances cp where cp.user_id=v_user_id and cp.ends_at>now()) then raise exception 'You are serving a community penance. You can return to the yard when it ends.';end if;
 if exists(select 1 from public.agbero_territories t where t.active=true) and not exists(select 1 from public.agbero_memberships m where m.citizen_id=v_user_id and m.status='inside') then raise exception 'Enter an Agbero territory before joining the street.';end if;
 if p_intensity is null or p_intensity not between 1 and 3 then raise exception 'Choose a valid intensity level.';end if;
 if p_opponent_id is null or p_opponent_id=v_user_id then raise exception 'Choose another citizen to call out.';end if;
 select p.author_id into v_post_author from public.posts p where p.id=p_post_id;
 if v_post_author is null then raise exception 'This conversation no longer exists.';end if;
 if not exists(select 1 from public.profiles pr where pr.id=p_opponent_id) then raise exception 'That citizen could not be found.';end if;
 if p_opponent_id<>v_post_author and not exists(select 1 from public.replies r where r.post_id=p_post_id and r.author_id=p_opponent_id) then raise exception 'You can only call out a citizen who has joined this conversation.';end if;
 update public.argument_challenges ac set status='expired',ended_at=now() where ac.post_id=p_post_id and ac.status='pending' and ac.expires_at<=now() and((ac.challenger_id=v_user_id and ac.challenged_id=p_opponent_id)or(ac.challenger_id=p_opponent_id and ac.challenged_id=v_user_id));
 select count(*) into v_recent_count from public.argument_challenges ac where ac.challenger_id=v_user_id and ac.created_at>now()-interval '24 hours';
 if v_recent_count>=10 then raise exception 'You have reached today’s callout limit. Try again later.';end if;
 insert into public.argument_challenges(post_id,challenger_id,challenged_id,intensity,status,accepted_at) values(p_post_id,v_user_id,p_opponent_id,p_intensity,'active',now()) returning * into v_result;
 return v_result;
exception when unique_violation then raise exception 'There is already an open callout between these citizens in this conversation.';
end;$function$;
revoke all on function public.create_argument_challenge(uuid,uuid,smallint) from public,anon;
grant execute on function public.create_argument_challenge(uuid,uuid,smallint) to authenticated;