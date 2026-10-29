begin;
create table public.app_notification_claims(user_id uuid not null references public.profiles(id) on delete cascade,
 event_key text not null check(length(event_key)<200), target_user uuid not null references public.profiles(id) on delete cascade,
 created_at timestamptz not null default now(),primary key(user_id,event_key));
alter table public.app_notification_claims enable row level security;
revoke all on public.app_notification_claims from anon,authenticated;
create function public.app_claim_notification(event_key text,target_user uuid) returns boolean
language plpgsql security definer set search_path='' as $$
declare me uuid:=auth.uid(); affected integer;
begin
 if me is null or me=target_user then return false; end if;
 perform pg_advisory_xact_lock(hashtextextended(me::text,11));
 if (select count(*) from public.app_notification_claims where user_id=me and created_at>now()-interval '1 hour')>=120 then return false; end if;
 insert into public.app_notification_claims(user_id,event_key,target_user) values(me,event_key,target_user) on conflict do nothing;
 get diagnostics affected=row_count;
 return affected=1;
end $$;
revoke all on function public.app_claim_notification(text,uuid) from public,anon;
grant execute on function public.app_claim_notification(text,uuid) to authenticated;
commit;
