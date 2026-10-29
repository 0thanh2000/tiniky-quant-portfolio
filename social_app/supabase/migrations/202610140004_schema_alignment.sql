-- Matched to the schema_export supplied on 2026-10-14.
-- Apply after 001, 002 and 003. No existing rows are deleted or rewritten.
begin;

-- Post editing was blocked because the exported schema had no UPDATE policy.
create policy app_posts_update_own on public.posts for update to authenticated
  using(user_id=auth.uid()) with check(user_id=auth.uid());
create policy app_posts_update_guard on public.posts as restrictive for update to authenticated
  using(user_id=auth.uid()) with check(user_id=auth.uid());
revoke update on public.posts from public,anon,authenticated;
revoke update(id,user_id,created_at) on public.posts from public,anon,authenticated;
grant update(content,image_url,video_url,media) on public.posts to authenticated;
grant select,insert,delete on public.posts to authenticated;
revoke insert,update,delete on public.posts from anon;

-- Both comment sheets expose deletion of the signed-in user's own comments.
create policy app_comments_delete_own on public.comments for delete to authenticated using(user_id=auth.uid());
create policy app_comments_delete_guard on public.comments as restrictive for delete to authenticated using(user_id=auth.uid());
create policy app_video_comments_delete_own on public.video_comments for delete to authenticated using(user_id=auth.uid());
create policy app_video_comments_delete_guard on public.video_comments as restrictive for delete to authenticated using(user_id=auth.uid());
grant select,insert,delete on public.comments,public.video_comments to authenticated;
revoke update on public.comments,public.video_comments from public,anon,authenticated;
revoke insert,delete on public.comments,public.video_comments from anon;

-- The old ALL policy exposed only one's own outgoing follows. Signed-in users
-- need SELECT for public follower/following lists; write access stays personal.
create policy app_follows_read on public.follows for select to authenticated using(true);
create policy app_follows_insert_guard on public.follows as restrictive for insert to authenticated
  with check(follower_id=auth.uid() and follower_id<>following_id);
create policy app_follows_delete_guard on public.follows as restrictive for delete to authenticated using(follower_id=auth.uid());
grant select,insert,delete on public.follows to authenticated;
revoke update on public.follows from public,anon,authenticated;
create policy app_follows_no_update on public.follows as restrictive for update to authenticated using(false);
revoke insert,delete on public.follows from anon;

-- RLS controls rows, while column grants protect badges/counters from edits.
-- The existing auth signup trigger still creates profiles as its table owner.
revoke insert,update,delete on public.profiles from public,anon,authenticated;
revoke update(id,is_verified,verified_type,follower_count,following_count,friend_count,created_at)
  on public.profiles from public,anon,authenticated;
grant select on public.profiles to anon,authenticated;
grant update(username,full_name,avatar_url,bio,cover_url,birthday,gender,hometown,
  current_city,relationship_status,work,education,website) on public.profiles to authenticated;

-- The exported "videos update views" policy used USING(true), permitting
-- edits to other people's videos. Keep it composed with a restrictive guard.
create policy app_videos_update_own on public.videos for update to authenticated
  using(user_id=auth.uid()) with check(user_id=auth.uid());
create policy app_videos_update_guard on public.videos as restrictive for update to authenticated
  using(user_id=auth.uid()) with check(user_id=auth.uid());
revoke update on public.videos from public,anon,authenticated;
revoke update(id,user_id,views,created_at) on public.videos from public,anon,authenticated;
create policy app_videos_anon_no_update on public.videos as restrictive for update to anon using(false);
grant update(video_url,thumbnail_url,caption,music_id,music_name,duration,music_url,
  overlay_text,overlay_x,overlay_y,overlay_font_size,overlay_color,original_volume,music_volume)
  on public.videos to authenticated;
grant select,insert,delete on public.videos to authenticated;
revoke insert,delete on public.videos from anon;

-- Notifications come from the existing database event triggers, not arbitrary
-- client inserts. A recipient may only change the read state of their rows.
revoke all on public.notifications from public,anon,authenticated;
grant select,delete on public.notifications to authenticated;
grant update(is_read) on public.notifications to authenticated;
create policy app_notifications_owner_guard on public.notifications as restrictive for all to authenticated
  using(user_id=auth.uid()) with check(user_id=auth.uid());
create policy app_notifications_no_client_insert on public.notifications as restrictive for insert to anon,authenticated with check(false);
revoke update(id,user_id,actor_id,type,target_id,content,created_at)
  on public.notifications from public,anon,authenticated;

-- Anonymous uploads to avatars were allowed by the exported public policy.
-- New avatar/cover uploads already use <user UUID>/filename in the Flutter app.
create policy app_avatar_insert_guard on storage.objects as restrictive for insert to authenticated
  with check(bucket_id<>'avatars' or split_part(name,'/',1)=auth.uid()::text);
create policy app_avatar_update_guard on storage.objects as restrictive for update to authenticated
  using(bucket_id<>'avatars' or (split_part(name,'/',1)=auth.uid()::text and owner=auth.uid()))
  with check(bucket_id<>'avatars' or (split_part(name,'/',1)=auth.uid()::text and owner=auth.uid()));
create policy app_avatar_delete_guard on storage.objects as restrictive for delete to authenticated
  using(bucket_id<>'avatars' or (split_part(name,'/',1)=auth.uid()::text and owner=auth.uid()));
create policy app_avatar_anon_insert_guard on storage.objects as restrictive for insert to anon
  with check(bucket_id<>'avatars');
create policy app_avatar_anon_update_guard on storage.objects as restrictive for update to anon
  using(bucket_id<>'avatars') with check(bucket_id<>'avatars');
create policy app_avatar_anon_delete_guard on storage.objects as restrictive for delete to anon
  using(bucket_id<>'avatars');
update storage.buckets set file_size_limit=10485760 where id='avatars'
  and (file_size_limit is null or file_size_limit>10485760);

-- Preserve the exported signup behavior, but qualify names in definer code.
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  insert into public.profiles(id,username,full_name)
  values(new.id,coalesce(new.raw_user_meta_data->>'username','user_'||substr(new.id::text,1,8)),
    coalesce(new.raw_user_meta_data->>'full_name',''));
  return new;
end $$;
create or replace function public.get_follow_counts(user_uuid uuid)
returns table(followers bigint,following bigint)
language sql stable security definer set search_path='' as $$
  select (select count(*) from public.follows where following_id=user_uuid),
    (select count(*) from public.follows where follower_id=user_uuid);
$$;
create or replace function public.is_following(follower uuid,following uuid) returns boolean
language sql stable security definer set search_path='' as $$
  select exists(select 1 from public.follows f where f.follower_id=follower and f.following_id=following);
$$;
create or replace function public.get_friendship_status(user_a uuid,user_b uuid) returns text
language sql stable security definer set search_path='' as $$
  select case when auth.uid() in(user_a,user_b) then coalesce((
    select f.status from public.friendships f
    where (f.user_id=user_a and f.friend_id=user_b) or (f.user_id=user_b and f.friend_id=user_a)
    order by case when f.status='accepted' then 0 else 1 end limit 1
  ),'none') else 'none' end;
$$;
create or replace function public.get_trending_hashtags(days_back integer default 7,max_count integer default 20)
returns table(hashtag text,post_count bigint)
language sql stable security definer set search_path='' as $$
  select lower(m.tags[1]),count(distinct p.id)
  from public.posts p
  cross join lateral regexp_matches(p.content,'#[A-Za-z0-9_À-ỹ]+','g') as m(tags)
  where p.created_at>now()-make_interval(days=>greatest(1,least(days_back,90)))
  group by lower(m.tags[1]) order by count(distinct p.id) desc,lower(m.tags[1])
  limit greatest(1,least(max_count,100));
$$;

-- Retain every original notification event, including friend acceptance, and
-- give media-only comments a readable notification preview.
create or replace function public.create_notification() returns trigger
language plpgsql security definer set search_path='' as $$
declare recipient uuid; actor uuid; kind text; target uuid; preview text;
begin
  if tg_table_name='likes' then
    actor:=new.user_id; target:=new.post_id; kind:='like_post'; preview:='đã thích bài viết của bạn';
    select user_id into recipient from public.posts where id=new.post_id;
  elsif tg_table_name='comments' then
    actor:=new.user_id; target:=new.post_id; kind:='comment_post';
    preview:=case when length(btrim(new.content))>0 then left(new.content,2000)
      when new.media->>'kind'='video' then 'đã bình luận bằng video' else 'đã bình luận bằng ảnh' end;
    select user_id into recipient from public.posts where id=new.post_id;
  elsif tg_table_name='video_likes' then
    actor:=new.user_id; target:=new.video_id; kind:='like_video'; preview:='đã thích video của bạn';
    select user_id into recipient from public.videos where id=new.video_id;
  elsif tg_table_name='video_comments' then
    actor:=new.user_id; target:=new.video_id; kind:='comment_video';
    preview:=case when length(btrim(new.content))>0 then left(new.content,2000)
      when new.media->>'kind'='video' then 'đã bình luận bằng video' else 'đã bình luận bằng ảnh' end;
    select user_id into recipient from public.videos where id=new.video_id;
  elsif tg_table_name='follows' then
    actor:=new.follower_id; recipient:=new.following_id; kind:='follow'; preview:='đã theo dõi bạn';
  elsif tg_table_name='friendships' then
    if tg_op='INSERT' and new.status='pending' then
      actor:=new.user_id; recipient:=new.friend_id; kind:='friend_request'; preview:='đã gửi lời mời kết bạn';
    elsif tg_op='UPDATE' and new.status='accepted' and old.status='pending' then
      actor:=new.friend_id; recipient:=new.user_id; kind:='friend_accept'; preview:='đã chấp nhận lời mời kết bạn';
    else return new;
    end if;
  else return new;
  end if;
  if recipient is null or actor is null or recipient=actor then return new; end if;
  insert into public.notifications(user_id,actor_id,type,target_id,content)
    values(recipient,actor,kind,target,preview);
  return new;
end $$;
revoke all on function public.handle_new_user(),public.create_notification() from public,anon,authenticated;
revoke all on function public.get_follow_counts(uuid),public.is_following(uuid,uuid),
  public.get_friendship_status(uuid,uuid),public.get_trending_hashtags(integer,integer) from public,anon;
grant execute on function public.get_follow_counts(uuid),public.is_following(uuid,uuid),
  public.get_friendship_status(uuid,uuid),public.get_trending_hashtags(integer,integer) to authenticated;

-- Re-add only the affected tables to remove any explicit old column list;
-- preserve the other tables already present in the publication.
do $$ declare t text; begin
  if exists(select 1 from pg_publication where pubname='supabase_realtime' and not puballtables) then
    foreach t in array array['posts','comments','messages','video_comments','videos'] loop
      if exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename=t) then
        execute format('alter publication supabase_realtime drop table public.%I',t);
      end if;
      execute format('alter publication supabase_realtime add table public.%I',t);
    end loop;
  end if;
end $$;
notify pgrst,'reload schema';
commit;
