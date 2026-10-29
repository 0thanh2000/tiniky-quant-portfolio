// Integration checks in an isolated PostgreSQL WASM instance, NEVER your server.
// npm install --prefix /tmp/social-sql-check @electric-sql/pglite
// PGLITE_MODULE=/tmp/social-sql-check/node_modules/@electric-sql/pglite/dist/index.js node tools/verify_database.mjs
import fs from 'node:fs';
import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import {isAbsolute} from 'node:path';
const modulePath=process.env.PGLITE_MODULE;
const {PGlite} = await import(modulePath && isAbsolute(modulePath) ? pathToFileURL(modulePath).href : modulePath || '@electric-sql/pglite');
const db = new PGlite();
const root = new URL('../', import.meta.url);
const exported = process.env.SCHEMA_FIXTURE === 'exported';
if (exported) {
 await db.exec(fs.readFileSync(new URL('tools/fixtures/supabase_export_20261014.sql',root),'utf8'));
} else await db.exec(`
create role anon; create role authenticated; create schema auth; create schema storage;
create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
grant usage on schema public,auth,storage to authenticated,anon; grant execute on function auth.uid() to authenticated,anon;
create table public.profiles(id uuid primary key,username text,avatar_url text,is_verified boolean default false,verified_type text);
create table public.posts(id uuid primary key default gen_random_uuid(),user_id uuid references profiles,content text, image_url text,created_at timestamptz default now());
create table public.videos(id uuid primary key default gen_random_uuid(),user_id uuid references profiles,video_url text,created_at timestamptz default now());
create table public.comments(id uuid primary key default gen_random_uuid(),post_id uuid references posts,user_id uuid references profiles,content text not null,created_at timestamptz default now());
create table public.video_comments(id uuid primary key default gen_random_uuid(),video_id uuid references videos,user_id uuid references profiles,content text not null,created_at timestamptz default now());
create table public.conversations(id uuid primary key default gen_random_uuid(),user1 uuid references profiles,user2 uuid references profiles);
create table public.messages(id uuid primary key default gen_random_uuid(),conversation_id uuid references conversations,sender_id uuid references profiles,content text not null,created_at timestamptz default now());
create table public.friendships(id uuid primary key default gen_random_uuid(),user_id uuid references profiles,friend_id uuid references profiles,status text);
create table public.follows(follower_id uuid references profiles,following_id uuid references profiles);
create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
create table storage.objects(id uuid default gen_random_uuid(),bucket_id text,name text);
alter table storage.objects enable row level security;
grant select,insert,update,delete on all tables in schema public,storage to authenticated,anon;
-- Deliberately broad old policies: new restrictive policies must still protect users.
alter table public.messages enable row level security;
create policy old_broad_messages on public.messages for all to authenticated using(true) with check(true);
alter table public.conversations enable row level security;
create policy old_broad_conversations on public.conversations for all to authenticated using(true) with check(true);
create policy old_broad_storage on storage.objects for all to authenticated,anon using(true) with check(true);
`);
for (const name of ['202610130001_social_features.sql','202610130002_upload_limits.sql','202610130003_notification_limits.sql',
 ...(exported ? ['202610140004_schema_alignment.sql'] : [])]) {
  await db.exec(fs.readFileSync(new URL(`supabase/migrations/${name}`, root), 'utf8'));
}
const a='10000000-0000-0000-0000-000000000001', b='10000000-0000-0000-0000-000000000002', c='10000000-0000-0000-0000-000000000003';
if (exported) {
 await db.query(`insert into auth.users(id,raw_user_meta_data) values($1,'{"username":"A"}'),($2,'{"username":"B"}'),($3,'{"username":"C"}')`,[a,b,c]);
} else await db.query(`insert into profiles(id,username) values($1,'A'),($2,'B'),($3,'C')`,[a,b,c]);
async function as(id){ await db.exec('reset role'); await db.query(`select set_config('request.jwt.claim.sub',$1,false)`,[id]); await db.exec("select set_config('request.jwt.claim.role','authenticated',false)"); await db.exec('set role authenticated'); }
async function scalar(sql,params=[]){ return Object.values((await db.query(sql,params)).rows[0])[0]; }
let passed=0;
async function test(name, fn){await fn(); console.log('PASS',name); passed++;}
await as(a);
let conversation,callId;
await test('friend request creates follow atomically, repeated request is idempotent',async()=>{
 await db.query('select app_request_friend($1)',[b]); await db.query('select app_request_friend($1)',[b]);
 assert.equal(Number(await scalar('select count(*) from friendships')),1);
 assert.equal(Number(await scalar('select count(*) from follows where follower_id=$1 and following_id=$2',[a,b])),1);
});
await test('sender cannot accept own request',async()=>{
 const r=await db.query(`update friendships set status='accepted' where user_id=$1 returning id`,[a]); assert.equal(r.rows.length,0);
});
await test('recipient acceptance creates reverse follow',async()=>{
 await as(b); await db.exec(`update friendships set status='accepted'`);
 assert.equal(Number(await scalar(`select count(*) from follows`)),2);
});
await test('third party cannot change friend endpoints',async()=>{
 await as(c); const r=await db.query(`update friendships set friend_id=$1 returning id`,[c]); assert.equal(r.rows.length,0);
});
await test('profile friends lists accepted friends',async()=>{
 assert.equal((await scalar('select app_profile_friends($1)',[a]))[0].id,b);
});
await test('conversation creation is idempotent in both directions',async()=>{
 await as(a); conversation=await scalar('select app_open_conversation($1)',[b]);
 await as(b); assert.equal(await scalar('select app_open_conversation($1)',[a]),conversation);
});
await test('participant can send private media, outsider cannot read messages or conversations',async()=>{
 await as(a); await db.query(`insert into messages(conversation_id,sender_id,content,media) values($1,$2,'', $3::jsonb)`,[conversation,a,JSON.stringify({kind:'image',storage_path:`${conversation}/${a}/photo.jpg`,url:''})]);
 await as(c); assert.equal(Number(await scalar('select count(*) from messages')),0);assert.equal(Number(await scalar('select count(*) from conversations')),0);
 await assert.rejects(db.query(`insert into messages(conversation_id,sender_id,content) values($1,$2,'intrusion')`,[conversation,c]));
});
await test('cannot spoof message sender or move an existing message',async()=>{
 await as(b); await assert.rejects(db.query(`insert into messages(conversation_id,sender_id,content) values($1,$2,'spoof')`,[conversation,a]));
 const r=await db.query(`update messages set sender_id=$1 returning id`,[b]);assert.equal(r.rows.length,0);
});
await test('private bucket path allows recipient reading, blocks outsider even under broad old policies',async()=>{
 await as(a);await db.query(`insert into storage.objects(bucket_id,name) values('chat-media',$1)`,[`${conversation}/${a}/photo.jpg`]);
 await as(b);assert.equal(Number(await scalar('select count(*) from storage.objects')),1);
 const removed=await db.query(`delete from storage.objects returning id`);assert.equal(removed.rows.length,0);
 await as(c);assert.equal(Number(await scalar('select count(*) from storage.objects')),0);
 await assert.rejects(db.query(`insert into storage.objects(bucket_id,name) values('chat-media',$1)`,[`${conversation}/${c}/bad.jpg`]));
});
await test('valid caller can start, a busy participant blocks second call',async()=>{
 await as(a);const call=await scalar(`select app_start_call($1,$2,true,'valid-offer-sdp')`,[conversation,b]);callId=call.id;
 await as(c);const other=await scalar('select app_open_conversation($1)',[b]);
 await assert.rejects(db.query(`select app_start_call($1,$2,false,'valid-other-offer')`,[other,b]));
});
await test('outsider cannot see call or insert signaling candidates',async()=>{
 await as(c); assert.equal(Number(await scalar('select count(*) from app_calls')),0);
 await assert.rejects(db.query(`insert into app_call_candidates(call_id,sender_id,candidate) values($1,$2,'{}')`,[callId,c]));
});
await test('only callee can answer; caller can end; cannot resurrect ended call',async()=>{
 await as(a);await assert.rejects(db.query(`select app_answer_call($1,'valid-answer-sdp')`,[callId]));
 await as(b);await db.query(`select app_answer_call($1,'valid-answer-sdp')`,[callId]);
 assert.equal(await scalar('select status from app_calls where id=$1',[callId]),'accepted');
 await as(a);await db.query(`select app_finish_call($1,'ended')`,[callId]);
 await as(b);await assert.rejects(db.query(`select app_answer_call($1,'valid-answer-sdp')`,[callId]));
});
await test('upload permit is limited per authenticated user',async()=>{
 await as(a); for(let i=0;i<60;i++)await db.exec('select app_upload_permit()');
 await assert.rejects(db.exec('select app_upload_permit()'));
 await as(b);await db.exec('select app_upload_permit()');
});
await test('push deduplicates events',async()=>{
 await as(a); assert.equal(await scalar('select app_claim_notification($1,$2)',['chat:test',b]),true);
 assert.equal(await scalar('select app_claim_notification($1,$2)',['chat:test',b]),false);
});
await test('schema export executes without reading application data',async()=>{
 await db.exec('reset role'); const result=await db.query(fs.readFileSync(new URL('supabase/export_structure.sql',root),'utf8'));assert.ok(result.rows[0].schema_export.columns.length>0);
});
if (exported) {
 let post,video,comment;
 await test('owner can edit a post; other users cannot; identity columns stay immutable',async()=>{
  await as(a);post=await scalar(`insert into public.posts(user_id,content) values($1,'Original') returning id`,[a]);
  await db.query(`update public.posts set content='Edited',media='[{"kind":"image","url":"https://example.com/p.jpg"}]' where id=$1`,[post]);
  assert.equal(await scalar('select content from public.posts where id=$1',[post]),'Edited');
  await assert.rejects(db.query(`update public.posts set user_id=$1 where id=$2`,[b,post]));
  await as(b); assert.equal((await db.query(`update public.posts set content='Intrusion' where id=$1 returning id`,[post])).rows.length,0);
 });
 await test('media-only comments produce notification previews and only authors can delete',async()=>{
  await as(b);comment=await scalar(`insert into public.comments(user_id,post_id,content,media) values($1,$2,'','{"kind":"video","url":"https://example.com/c.mp4"}') returning id`,[b,post]);
  await as(a);assert.equal(await scalar(`select content from public.notifications where type='comment_post' and target_id=$1 order by created_at desc limit 1`,[post]),'đã bình luận bằng video');
  assert.equal((await db.query('delete from public.comments where id=$1 returning id',[comment])).rows.length,0);
  await as(b);assert.equal((await db.query('delete from public.comments where id=$1 returning id',[comment])).rows.length,1);
 });
 await test('profile text can change, but verified badges and cached counters cannot',async()=>{
  await as(a);await db.query(`update public.profiles set bio='New bio' where id=$1`,[a]);
  await assert.rejects(db.query(`update public.profiles set is_verified=true where id=$1`,[a]));
  await assert.rejects(db.query(`update public.profiles set verified_type='admin' where id=$1`,[a]));
  await assert.rejects(db.query(`update public.profiles set follower_count=999999 where id=$1`,[a]));
  assert.equal(await scalar('select bio from public.profiles where id=$1',[a]),'New bio');
 });
 await test('broad old video UPDATE policy cannot modify other users or forge view counts',async()=>{
  await as(a);video=await scalar(`insert into public.videos(user_id,video_url,caption) values($1,'https://example.com/v.mp4','Mine') returning id`,[a]);
  await db.query(`update public.videos set caption='Edited caption' where id=$1`,[video]);
  await assert.rejects(db.query(`update public.videos set views=999999 where id=$1`,[video]));
  await as(b);assert.equal((await db.query(`update public.videos set caption='Intrusion' where id=$1 returning id`,[video])).rows.length,0);
 });
 await test('video comment author can delete their media comment',async()=>{
  await as(b);const id=await scalar(`insert into public.video_comments(user_id,video_id,content,media) values($1,$2,'','{"kind":"image","url":"https://example.com/c.jpg"}') returning id`,[b,video]);
  await as(c);assert.equal((await db.query('delete from public.video_comments where id=$1 returning id',[id])).rows.length,0);
  await as(b);assert.equal((await db.query('delete from public.video_comments where id=$1 returning id',[id])).rows.length,1);
 });
 await test('follower lists are readable while writes remain limited to the actor',async()=>{
  await as(c);assert.equal(Number(await scalar('select count(*) from public.follows')),2);
  assert.equal((await db.query('delete from public.follows returning follower_id')).rows.length,0);
  await assert.rejects(db.query('insert into public.follows(follower_id,following_id) values($1,$2)',[a,c]));
  await assert.rejects(db.query('update public.follows set following_id=$1',[c]));
 });
 await test('notifications are private and cannot be forged or have their content edited',async()=>{
  await as(a);const id=await scalar('select id from public.notifications limit 1');assert.ok(id);
  await db.query('update public.notifications set is_read=true where id=$1',[id]);
  await assert.rejects(db.query("update public.notifications set content='Forged' where id=$1",[id]));
  await assert.rejects(db.query("insert into public.notifications(user_id,actor_id,type) values($1,$2,'follow')",[a,b]));
  await as(c);assert.equal(Number(await scalar('select count(*) from public.notifications')),0);
 });
 await test('legacy notification triggers still record likes and friend acceptance',async()=>{
  await as(b);await db.query('insert into public.likes(user_id,post_id) values($1,$2)',[b,post]);
  await as(a);assert.equal(Number(await scalar("select count(*) from public.notifications where type='like_post' and target_id=$1",[post])),1);
  assert.equal(Number(await scalar("select count(*) from public.notifications where type='friend_accept'")),1);
 });
 await test('avatar upload permits own folder and denies someone else\'s folder',async()=>{
  await as(a);await db.query("insert into storage.objects(bucket_id,name) values('avatars',$1)",[`${a}/avatar.jpg`]);
  await assert.rejects(db.query("insert into storage.objects(bucket_id,name) values('avatars',$1)",[`${b}/intrusion.jpg`]));
 });
 await test('anonymous avatar upload and notifications insert are blocked',async()=>{
  await db.exec('reset role');await db.exec("select set_config('request.jwt.claim.sub','',false)");await db.exec("select set_config('request.jwt.claim.role','anon',false)");await db.exec('set role anon');
  await assert.rejects(db.query("insert into storage.objects(bucket_id,name) values('avatars','random.jpg')"));
  await assert.rejects(db.query("insert into public.notifications(user_id,actor_id,type) values($1,$2,'follow')",[a,b]));
  await assert.rejects(db.query('select public.app_profile_friends($1)',[a]));
 });
 await test('private friendship-status RPC does not reveal another pair\'s pending state',async()=>{
  await as(c);assert.equal(await scalar('select public.get_friendship_status($1,$2)',[a,b]),'none');
  await as(a);assert.equal(await scalar('select public.get_friendship_status($1,$2)',[a,b]),'accepted');
 });
 await test('legacy definer RPCs use public tables even if a temporary table shadows their name',async()=>{
  await as(a);await db.exec('create temp table follows(follower_id uuid,following_id uuid)');
  assert.equal(Number((await db.query('select * from public.get_follow_counts($1)',[a])).rows[0].followers),1);
  assert.equal(await scalar('select public.is_following($1,$2)',[a,b]),true);
  await db.exec('drop table pg_temp.follows');
 });
 await test('Vietnamese hashtags remain searchable and repeat tags in one post count once',async()=>{
  await as(a);await db.query("update public.posts set content='#Flutter #Flutter #ứngdụng' where id=$1",[post]);
  const rows=(await db.query('select * from public.get_trending_hashtags()')).rows;
  assert.equal(Number(rows.find(r=>r.hashtag==='#flutter').post_count),1);
  assert.ok(rows.find(r=>r.hashtag==='#ứngdụng'));
 });
 await test('realtime publication includes new media columns and preserves unrelated tables',async()=>{
  await db.exec('reset role');
  const rows=(await db.query("select tablename,attnames from pg_publication_tables where pubname='supabase_realtime'")).rows;
  for(const name of ['posts','comments','messages','video_comments'])assert.ok(rows.find(r=>r.tablename===name).attnames.includes('media'));
  assert.ok(rows.find(r=>r.tablename==='likes'));assert.ok(rows.find(r=>r.tablename==='friendships'));
 });
 const installerDb=new PGlite();
 await test('SQL Editor installer applies all migrations in one transaction and preserves existing rows',async()=>{
  await installerDb.exec(fs.readFileSync(new URL('tools/fixtures/supabase_export_20261014.sql',root),'utf8'));
  await installerDb.query(`insert into auth.users(id,raw_user_meta_data) values($1,'{"username":"Legacy"}')`,[a]);
  await installerDb.query(`insert into public.posts(user_id,content,image_url) values($1,'Legacy post','https://example.com/legacy.jpg')`,[a]);
  await installerDb.exec(fs.readFileSync(new URL('supabase/INSTALLER_SQL_EDITOR.sql',root),'utf8'));
  assert.equal((await installerDb.query('select content from public.posts')).rows[0].content,'Legacy post');
  assert.equal((await installerDb.query("select count(*)::integer as n from pg_policies where policyname='app_posts_update_own'")).rows[0].n,1);
 });
 await test('installer refuses a repeated installation without discarding data',async()=>{
  await assert.rejects(installerDb.exec(fs.readFileSync(new URL('supabase/INSTALLER_SQL_EDITOR.sql',root),'utf8')));
  await installerDb.exec('rollback');
  assert.equal((await installerDb.query('select content from public.posts')).rows[0].content,'Legacy post');
 });
 await installerDb.close();
 const duplicateDb=new PGlite();
 await test('duplicate conversations abort the whole installer and preserve both histories',async()=>{
  await duplicateDb.exec(fs.readFileSync(new URL('tools/fixtures/supabase_export_20261014.sql',root),'utf8'));
  await duplicateDb.query(`insert into auth.users(id,raw_user_meta_data) values($1,'{"username":"A"}'),($2,'{"username":"B"}')`,[a,b]);
  const first=(await duplicateDb.query('insert into public.conversations(user1,user2) values($1,$2) returning id',[a,b])).rows[0].id;
  const second=(await duplicateDb.query('insert into public.conversations(user1,user2) values($1,$2) returning id',[b,a])).rows[0].id;
  await duplicateDb.query("insert into public.messages(conversation_id,sender_id,content) values($1,$3,'First history'),($2,$3,'Second history')",[first,second,a]);
  const counts=(await duplicateDb.query(fs.readFileSync(new URL('supabase/KIEM_TRA_TRUOC.sql',root),'utf8'))).rows;
  assert.equal(Number(counts.find(r=>r.issue==='conversation_duplicate_pairs').issue_count),1);
  await assert.rejects(duplicateDb.exec(fs.readFileSync(new URL('supabase/INSTALLER_SQL_EDITOR.sql',root),'utf8')));
  await duplicateDb.exec('rollback');
  assert.equal((await duplicateDb.query('select count(*)::integer as n from public.messages')).rows[0].n,2);
  assert.equal((await duplicateDb.query("select count(*)::integer as n from information_schema.columns where table_schema='public' and table_name='posts' and column_name='media'")).rows[0].n,0);
 });
 await duplicateDb.close();
}
console.log(`${passed} integration tests passed. ${exported ? 'Public schema recreated from the supplied export; Auth/Storage/grants modeled locally. No live server tests.' : 'Synthetic fixture only.'}`);
await db.close();
