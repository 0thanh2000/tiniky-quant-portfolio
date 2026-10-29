begin;
create table public.app_upload_events(user_id uuid not null references public.profiles(id) on delete cascade, created_at timestamptz not null default now());
create index on public.app_upload_events(user_id,created_at);
alter table public.app_upload_events enable row level security;
revoke all on public.app_upload_events from anon,authenticated;
create function public.app_upload_permit() returns void language plpgsql security definer set search_path='' as $$
declare me uuid:=auth.uid();
begin
 if me is null then raise exception 'Authentication required'; end if;
 perform pg_advisory_xact_lock(hashtextextended(me::text,9));
 if (select count(*) from public.app_upload_events where user_id=me and created_at>now()-interval '1 hour')>=60 then raise exception 'Too many uploads'; end if;
 delete from public.app_upload_events where user_id=me and created_at<now()-interval '1 day';
 insert into public.app_upload_events(user_id) values(me);
end $$;
revoke all on function public.app_upload_permit() from public,anon;
grant execute on function public.app_upload_permit() to authenticated;
commit;
