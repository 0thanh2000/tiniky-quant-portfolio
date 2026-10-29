-- READ ONLY: counts only. Every issue_count should be zero before installing.
select 'conversation_duplicate_pairs' as issue,count(*) as issue_count from (
  select least(user1,user2),greatest(user1,user2) from public.conversations
  group by least(user1,user2),greatest(user1,user2) having count(*)>1
) x
union all
select 'friendship_duplicate_pairs',count(*) from (
  select least(user_id,friend_id),greatest(user_id,friend_id) from public.friendships
  group by least(user_id,friend_id),greatest(user_id,friend_id) having count(*)>1
) x
union all
select 'conversation_invalid_members',count(*) from public.conversations
  where user1 is null or user2 is null or user1=user2
union all
select 'friendship_invalid_members_or_status',count(*) from public.friendships
  where user_id is null or friend_id is null or user_id=friend_id or status not in('pending','accepted')
union all
select 'migration_already_started',case when to_regclass('public.app_calls') is null
  and to_regclass('public.app_upload_events') is null
  and to_regclass('public.app_notification_claims') is null then 0 else 1 end;
