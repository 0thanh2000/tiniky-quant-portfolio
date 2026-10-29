-- For the diagnostic result supplied on 2026-10-14:
-- exactly one self-conversation with zero messages and one accepted self-friendship.
-- Run ONCE before INSTALLER_SQL_EDITOR.sql. Backups stay private in the database.
begin;
lock table public.conversations,public.messages,public.friendships in share row exclusive mode;
do $$ begin
  if (select count(*) from public.conversations where user1=user2)<>1
     or (select count(*) from public.friendships where user_id=friend_id and status='accepted')<>1 then
    raise exception 'Dữ liệu đã khác ảnh chẩn đoán. Dừng để kiểm tra lại; không có bản ghi nào bị xóa.';
  end if;
  if exists(select 1 from public.conversations where user1 is null or user2 is null)
     or exists(select 1 from public.friendships where user_id is null or friend_id is null
        or status is null or status not in('pending','accepted')
        or (user_id=friend_id and status<>'accepted')) then
    raise exception 'Có lỗi dữ liệu khác ngoài hai bản ghi đã xác nhận. Dừng để kiểm tra lại.';
  end if;
  if exists(select 1 from public.messages m join public.conversations c on c.id=m.conversation_id where c.user1=c.user2) then
    raise exception 'Hội thoại tự nhắn đã có tin nhắn. Dừng; không xóa hội thoại hoặc tin nhắn.';
  end if;
end $$;

create table if not exists public.app_repair_archive(
  operation_key text not null,
  source_table text not null,
  row_id uuid not null,
  snapshot jsonb not null,
  saved_at timestamptz not null default now(),
  primary key(operation_key,source_table,row_id)
);
alter table public.app_repair_archive enable row level security;
revoke all on public.app_repair_archive from public,anon,authenticated;
comment on table public.app_repair_archive is 'Private admin-only snapshots of invalid legacy rows removed during repair. Never expose in the app.';

insert into public.app_repair_archive(operation_key,source_table,row_id,snapshot)
  select 'self_pairs_20261014','conversations',c.id,to_jsonb(c)
  from public.conversations c where c.user1=c.user2;
insert into public.app_repair_archive(operation_key,source_table,row_id,snapshot)
  select 'self_pairs_20261014','friendships',f.id,to_jsonb(f)
  from public.friendships f where f.user_id=f.friend_id and f.status='accepted';

delete from public.conversations c where c.user1=c.user2
  and not exists(select 1 from public.messages m where m.conversation_id=c.id);
delete from public.friendships f where f.user_id=f.friend_id and f.status='accepted';
commit;

-- Expected: 2 rows archived. Messages and all valid relationships are retained.
select count(*) as so_ban_ghi_da_sao_luu
from public.app_repair_archive where operation_key='self_pairs_20261014';
