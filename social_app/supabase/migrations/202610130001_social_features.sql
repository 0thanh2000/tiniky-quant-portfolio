-- Additive migration for the existing Tiniky app. Review against exported schema first.
-- Run in a test project first. A failed preflight rolls back the entire transaction.
begin;
do $$
declare t text;
begin
  foreach t in array array['profiles','posts','comments','videos','video_comments','messages','conversations','friendships','follows'] loop
    if to_regclass('public.'||t) is null then raise exception 'Missing table public.%. Export the existing schema before applying this migration.', t; end if;
  end loop;
  foreach t in array array['profiles','posts','videos','conversations'] loop
    if not exists(select 1 from information_schema.columns where table_schema='public' and table_name=t and column_name='id' and udt_name='uuid') then
      raise exception 'Expected %.id to be UUID. Do not change existing IDs; adapt this migration to the exported schema.',t;
    end if;
  end loop;
  if exists(select 1 from public.conversations where user1 is null or user2 is null or user1=user2)
    or exists(select 1 from public.friendships where user_id is null or friend_id is null or user_id=friend_id or status not in('pending','accepted')) then
    raise exception 'Có hội thoại/quan hệ bạn bè thiếu thành viên hoặc trạng thái không hợp lệ. Chạy KIEM_TRA_TRUOC.sql và gửi kết quả; không xóa dữ liệu.';
  end if;
  if exists(select 1 from public.conversations group by least(user1,user2),greatest(user1,user2) having count(*)>1)
    or exists(select 1 from public.friendships group by least(user_id,friend_id),greatest(user_id,friend_id) having count(*)>1) then
    raise exception 'Có cặp hội thoại/bạn bè trùng hai chiều. Chạy KIEM_TRA_TRUOC.sql và gửi kết quả để xử lý giữ nguyên dữ liệu.';
  end if;
end $$;

alter table public.posts add column if not exists media jsonb not null default '[]'::jsonb;
alter table public.posts add column if not exists video_url text;
alter table public.comments add column if not exists media jsonb;
alter table public.video_comments add column if not exists media jsonb;
alter table public.messages add column if not exists media jsonb;

-- Existing single-image posts remain readable through a client-side fallback.
create or replace function public.app_valid_media(items jsonb) returns boolean
language plpgsql immutable set search_path = '' as $$
declare item jsonb;
begin
  if jsonb_typeof(items) <> 'array' or jsonb_array_length(items) > 10 then return false; end if;
  for item in select * from jsonb_array_elements(items) loop
    if jsonb_typeof(item) <> 'object' or coalesce(item->>'kind','') not in ('image','video')
      or coalesce(item->>'url','') !~ '^https://' then return false; end if;
  end loop;
  return true;
end $$;
alter table public.posts add constraint app_posts_media_valid check (public.app_valid_media(media)) not valid;
alter table public.comments add constraint app_comments_media_valid check (media is null or public.app_valid_media(jsonb_build_array(media))) not valid;
alter table public.video_comments add constraint app_video_comments_media_valid check (media is null or public.app_valid_media(jsonb_build_array(media))) not valid;
alter table public.messages add constraint app_messages_media_valid check (media is null or (
  jsonb_typeof(media)='object' and coalesce(media->>'kind','') in ('image','video')
  and coalesce(media->>'storage_path','') like conversation_id::text||'/'||sender_id::text||'/%'
  and coalesce(media->>'url','') = ''
)) not valid;

create index if not exists app_posts_user_created on public.posts(user_id, created_at desc);
create index if not exists app_posts_created on public.posts(created_at desc, id desc);
create index if not exists app_messages_conversation_created on public.messages(conversation_id, created_at desc, id desc);
create index if not exists app_comments_post_created on public.comments(post_id, created_at desc);
create index if not exists app_video_comments_video_created on public.video_comments(video_id, created_at desc);

-- Stop rather than deleting or merging existing duplicate conversations/friendships.
create unique index if not exists app_conversation_pair on public.conversations(least(user1,user2), greatest(user1,user2));
create unique index if not exists app_friendship_pair on public.friendships(least(user_id,friend_id), greatest(user_id,friend_id));
create unique index if not exists app_follow_pair on public.follows(follower_id,following_id);

create or replace function public.app_open_conversation(other_user uuid) returns uuid
language plpgsql security definer set search_path = '' as $$
declare me uuid := auth.uid(); result uuid;
begin
  if me is null or me=other_user or not exists(select 1 from public.profiles where id=other_user) then raise exception 'Invalid recipient'; end if;
  perform pg_advisory_xact_lock(hashtextextended(least(me,other_user)::text||greatest(me,other_user)::text, 0));
  select id into result from public.conversations where least(user1,user2)=least(me,other_user) and greatest(user1,user2)=greatest(me,other_user) limit 1;
  if result is null then insert into public.conversations(user1,user2) values(least(me,other_user),greatest(me,other_user)) returning id into result; end if;
  return result;
end $$;

create or replace function public.app_request_friend(other_user uuid) returns text
language plpgsql security definer set search_path = '' as $$
declare me uuid := auth.uid(); existing public.friendships%rowtype;
begin
  if me is null or me=other_user or not exists(select 1 from public.profiles where id=other_user) then raise exception 'Invalid friend'; end if;
  perform pg_advisory_xact_lock(hashtextextended(least(me,other_user)::text||greatest(me,other_user)::text, 1));
  select * into existing from public.friendships where least(user_id,friend_id)=least(me,other_user) and greatest(user_id,friend_id)=greatest(me,other_user) for update;
  if not found then
    insert into public.friendships(user_id,friend_id,status) values(me,other_user,'pending');
  elsif existing.status='pending' and existing.friend_id=me then
    update public.friendships set status='accepted' where id=existing.id;
  end if;
  insert into public.follows(follower_id,following_id) values(me,other_user) on conflict do nothing;
  return 'ok';
end $$;

create or replace function public.app_friend_follow_trigger() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.follows(follower_id,following_id) values(new.user_id,new.friend_id) on conflict do nothing;
  if new.status='accepted' then
    insert into public.follows(follower_id,following_id) values(new.friend_id,new.user_id) on conflict do nothing;
  end if;
  return new;
end $$;
create trigger app_friend_follow after insert or update of status on public.friendships
  for each row execute function public.app_friend_follow_trigger();

-- An existing broad UPDATE policy must not allow sender/recipient IDs to be changed.
create or replace function public.app_guard_friendship() returns trigger
language plpgsql set search_path = '' as $$
begin
  if auth.uid() is not null then
    if tg_op='INSERT' then
      if new.user_id<>auth.uid() or new.user_id=new.friend_id or new.status<>'pending' then raise exception 'Invalid friend request'; end if;
    else
      if new.user_id<>old.user_id or new.friend_id<>old.friend_id or new.id<>old.id
        or old.status<>'pending' or new.status<>'accepted' or old.friend_id<>auth.uid() then raise exception 'Invalid friendship transition'; end if;
    end if;
  end if;
  return new;
end $$;
create trigger app_guard_friendship before insert or update on public.friendships for each row execute function public.app_guard_friendship();

create or replace function public.app_profile_friends(profile_id uuid) returns jsonb
language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(x), '[]'::jsonb) from (
    select p.id,p.username,p.avatar_url from public.profiles p
    where auth.uid() is not null and exists(select 1 from public.friendships f where f.status='accepted'
      and ((f.user_id=profile_id and f.friend_id=p.id) or (f.friend_id=profile_id and f.user_id=p.id)))
    order by p.username limit 500
  ) x;
$$;

create or replace function public.app_conversation_list() returns jsonb
language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(x order by x.last_at desc nulls last), '[]'::jsonb) from (
    select c.id, jsonb_build_object('id',p.id,'username',p.username,'avatar_url',p.avatar_url,
      'is_verified',p.is_verified,'verified_type',p.verified_type) as profile,
      case when length(coalesce(m.content,''))>0 then m.content
        when m.media->>'kind'='video' then 'Video' when m.media is not null then 'Ảnh' else 'Chưa có tin nhắn' end as preview,
      m.created_at as last_at
    from public.conversations c join public.profiles p on p.id=case when c.user1=auth.uid() then c.user2 else c.user1 end
    left join lateral (select content,media,created_at from public.messages where conversation_id=c.id order by created_at desc,id desc limit 1) m on true
    where auth.uid() in (c.user1,c.user2) order by m.created_at desc nulls last limit 100
  ) x;
$$;

-- Restrictive guards compose with existing permissive policies rather than dropping them.
alter table public.conversations enable row level security;
alter table public.messages enable row level security;
alter table public.friendships enable row level security;
create policy app_conversation_member_guard on public.conversations as restrictive for all to authenticated
  using (auth.uid() in (user1,user2)) with check (auth.uid() in (user1,user2) and user1<>user2);
create policy app_conversation_read on public.conversations for select to authenticated using (auth.uid() in (user1,user2));
create policy app_conversation_no_client_update on public.conversations as restrictive for update to authenticated using (false);
create policy app_conversation_no_client_delete on public.conversations as restrictive for delete to authenticated using (false);
create policy app_message_member_guard on public.messages as restrictive for all to authenticated
  using (exists(select 1 from public.conversations c where c.id=conversation_id and auth.uid() in(c.user1,c.user2)))
  with check (sender_id=auth.uid() and exists(select 1 from public.conversations c where c.id=conversation_id and auth.uid() in(c.user1,c.user2)));
create policy app_messages_read on public.messages for select to authenticated using (true);
create policy app_messages_send on public.messages for insert to authenticated with check (sender_id=auth.uid());
create policy app_messages_immutable on public.messages as restrictive for update to authenticated using (false);
create policy app_messages_delete_own_guard on public.messages as restrictive for delete to authenticated using (sender_id=auth.uid());
create policy app_friendship_read_guard on public.friendships as restrictive for select to authenticated using (status='accepted' or auth.uid() in(user_id,friend_id));
create policy app_friendship_read on public.friendships for select to authenticated using (status='accepted' or auth.uid() in(user_id,friend_id));
create policy app_friendship_insert_guard on public.friendships as restrictive for insert to authenticated with check(user_id=auth.uid() and status='pending' and user_id<>friend_id);
create policy app_friendship_update_guard on public.friendships as restrictive for update to authenticated using(friend_id=auth.uid() and status='pending') with check(friend_id=auth.uid() and status='accepted');
create policy app_friendship_accept on public.friendships for update to authenticated using(friend_id=auth.uid() and status='pending') with check(friend_id=auth.uid() and status='accepted');
create policy app_friendship_delete_guard on public.friendships as restrictive for delete to authenticated using(auth.uid() in(user_id,friend_id));
create policy app_friendship_delete on public.friendships for delete to authenticated using(auth.uid() in(user_id,friend_id));
revoke all on public.conversations, public.messages, public.friendships from anon;
grant select on public.conversations to authenticated;
grant select,insert on public.messages to authenticated;
grant select,update,delete on public.friendships to authenticated;

-- Private attachments: both participants can read; only uploader can create/delete.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('chat-media','chat-media',false,52428800,array['image/jpeg','image/png','image/webp','image/gif','image/heic','image/heif','video/mp4','video/quicktime','video/webm'])
on conflict(id) do update set public=false,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;
create or replace function public.app_can_read_chat_path(path text) returns boolean
language sql stable security definer set search_path = '' as $$
 select auth.uid() is not null and exists(select 1 from public.conversations c
   where c.id::text=split_part(path,'/',1) and auth.uid() in(c.user1,c.user2));
$$;
create policy app_chat_storage_guard on storage.objects as restrictive for all to authenticated
using(bucket_id<>'chat-media' or public.app_can_read_chat_path(name))
with check(bucket_id<>'chat-media' or (public.app_can_read_chat_path(name) and split_part(name,'/',2)=auth.uid()::text));
create policy app_chat_storage_anon_guard on storage.objects as restrictive for all to anon using(bucket_id<>'chat-media') with check(bucket_id<>'chat-media');
create policy app_chat_storage_read on storage.objects for select to authenticated using(bucket_id='chat-media' and public.app_can_read_chat_path(name));
create policy app_chat_storage_insert on storage.objects for insert to authenticated with check(bucket_id='chat-media' and public.app_can_read_chat_path(name) and split_part(name,'/',2)=auth.uid()::text);
create policy app_chat_storage_delete on storage.objects for delete to authenticated using(bucket_id='chat-media' and split_part(name,'/',2)=auth.uid()::text);
create policy app_chat_storage_delete_guard on storage.objects as restrictive for delete to authenticated using(bucket_id<>'chat-media' or split_part(name,'/',2)=auth.uid()::text);
create policy app_chat_storage_no_overwrite on storage.objects as restrictive for update to authenticated using(bucket_id<>'chat-media');

-- Calls and trickle ICE signaling. The client cannot mutate calls directly.
create table public.app_calls (
 id uuid primary key default gen_random_uuid(),
 conversation_id uuid not null references public.conversations(id) on delete cascade,
 caller_id uuid not null references public.profiles(id) on delete cascade,
 callee_id uuid not null references public.profiles(id) on delete cascade,
 is_video boolean not null default false,
 status text not null default 'ringing' check(status in ('ringing','accepted','ended','declined','missed','failed')),
 offer text not null check(length(offer)<100000), answer text check(length(answer)<100000),
 created_at timestamptz not null default now(), answered_at timestamptz, ended_at timestamptz,
 expires_at timestamptz not null default now()+interval '60 seconds',
 caller_seen_at timestamptz not null default now(), callee_seen_at timestamptz,
 check(caller_id<>callee_id)
);
create table public.app_call_candidates (
 id bigint generated always as identity primary key,
 call_id uuid not null references public.app_calls(id) on delete cascade,
 sender_id uuid not null references public.profiles(id) on delete cascade,
 candidate jsonb not null check(jsonb_typeof(candidate)='object' and length(candidate::text)<4096),
 created_at timestamptz not null default now()
);
create index on public.app_calls(callee_id,status,expires_at);
create index on public.app_calls(caller_id,status,expires_at);
create index on public.app_call_candidates(call_id,id);
alter table public.app_calls enable row level security;
alter table public.app_call_candidates enable row level security;
create policy app_calls_read on public.app_calls for select to authenticated using(auth.uid() in(caller_id,callee_id));
create policy app_candidates_read on public.app_call_candidates for select to authenticated using(exists(select 1 from public.app_calls c where c.id=call_id and auth.uid() in(c.caller_id,c.callee_id)));
create policy app_candidates_insert on public.app_call_candidates for insert to authenticated with check(sender_id=auth.uid() and exists(select 1 from public.app_calls c where c.id=call_id and auth.uid() in(c.caller_id,c.callee_id) and c.status in ('ringing','accepted') and c.expires_at>now()));
revoke all on public.app_calls,public.app_call_candidates from anon,authenticated;
grant select on public.app_calls to authenticated;
grant select,insert on public.app_call_candidates to authenticated;
grant usage on sequence public.app_call_candidates_id_seq to authenticated;

create or replace function public.app_start_call(conversation uuid, callee uuid, with_video boolean, offer_sdp text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare me uuid:=auth.uid(); result public.app_calls%rowtype;
begin
 if me is null or me=callee or length(coalesce(offer_sdp,''))<10 then raise exception 'Invalid call'; end if;
 if not exists(select 1 from public.conversations where id=conversation and least(user1,user2)=least(me,callee) and greatest(user1,user2)=greatest(me,callee)) then raise exception 'Not a participant'; end if;
 -- Lock both users, in order: prevents simultaneous calls across different conversations.
 perform pg_advisory_xact_lock(hashtextextended(least(me,callee)::text,7));
 perform pg_advisory_xact_lock(hashtextextended(greatest(me,callee)::text,7));
 if exists(select 1 from public.app_calls where status in('ringing','accepted') and expires_at>now()
   and (caller_id in(me,callee) or callee_id in(me,callee))) then raise exception 'Một người đang bận cuộc gọi khác'; end if;
 insert into public.app_calls(conversation_id,caller_id,callee_id,is_video,offer) values(conversation,me,callee,with_video,offer_sdp) returning * into result;
 return to_jsonb(result);
end $$;
create or replace function public.app_answer_call(call_id uuid, answer_sdp text) returns void
language plpgsql security definer set search_path='' as $$
begin
 if length(coalesce(answer_sdp,''))<10 then raise exception 'Invalid answer'; end if;
 update public.app_calls set answer=answer_sdp,status='accepted',answered_at=now(),callee_seen_at=now(),expires_at=now()+interval '90 seconds'
 where id=call_id and callee_id=auth.uid() and status='ringing' and expires_at>now();
 if not found then raise exception 'Cuộc gọi đã kết thúc'; end if;
end $$;
create or replace function public.app_finish_call(call_id uuid, result text default 'ended') returns void
language plpgsql security definer set search_path='' as $$
begin
 if result not in ('ended','declined','missed','failed') then raise exception 'Invalid status'; end if;
 update public.app_calls set status=result,ended_at=now(),expires_at=now()
 where id=call_id and auth.uid() in(caller_id,callee_id) and status in('ringing','accepted');
end $$;
create or replace function public.app_call_heartbeat(call_id uuid) returns void
language plpgsql security definer set search_path='' as $$
begin
 update public.app_calls set
   caller_seen_at=case when caller_id=auth.uid() then now() else caller_seen_at end,
   callee_seen_at=case when callee_id=auth.uid() then now() else callee_seen_at end,
   expires_at=least(case when caller_id=auth.uid() then now() else caller_seen_at end,
                    case when callee_id=auth.uid() then now() else coalesce(callee_seen_at,now()) end)+interval '90 seconds'
 where id=call_id and auth.uid() in(caller_id,callee_id) and status='accepted' and expires_at>now();
end $$;

-- All new RPCs require a signed-in user; no anon/public execution grants.
do $$ declare f record; begin
 for f in select p.oid::regprocedure as signature from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname like 'app\_%' escape '\' loop
   execute format('revoke all on function %s from public, anon', f.signature);
 end loop;
end $$;
grant execute on function public.app_valid_media(jsonb),public.app_open_conversation(uuid),public.app_request_friend(uuid),public.app_profile_friends(uuid),
 public.app_conversation_list(),public.app_can_read_chat_path(text),public.app_start_call(uuid,uuid,boolean,text),
 public.app_answer_call(uuid,text),public.app_finish_call(uuid,text),public.app_call_heartbeat(uuid) to authenticated;
revoke all on function public.app_friend_follow_trigger(),public.app_guard_friendship() from authenticated;

-- Enable events for chat/comments/call inbox. Check current publication before adding.
do $$ declare t text; begin
 if exists(select 1 from pg_publication where pubname='supabase_realtime') then
  foreach t in array array['messages','comments','video_comments','app_calls'] loop
   if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename=t) then
    execute format('alter publication supabase_realtime add table public.%I',t);
   end if;
  end loop;
 end if;
end $$;
notify pgrst, 'reload schema';
commit;
