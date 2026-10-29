"""Build a LOCAL test fixture from the supplied schema export, never server data.

Usage: python tools/schema_to_fixture.py path/to/schema_export.json
The auth/storage platform scaffolding and initial grants are modeled separately;
the export includes no grants, user rows, storage objects or Auth internals.
"""
from pathlib import Path
import json
import sys

root = Path(__file__).resolve().parents[1]
schema = json.loads(Path(sys.argv[1]).read_text(encoding='utf-8-sig'))
def ident(value):
    return '"' + value.replace('"', '""') + '"'
def literal(value):
    return "'" + value.replace("'", "''") + "'"

sql = ["""-- LOCAL FIXTURE ONLY. DO NOT RUN THIS FILE ON SUPABASE.
-- Public columns, constraints, functions, policies and triggers come from the
-- user-supplied export. Platform internals/grants are modeled, not exported.
create role anon; create role authenticated; create schema auth; create schema storage;
create function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid
$$;
create function auth.role() returns text language sql stable as $$
  select nullif(current_setting('request.jwt.claim.role',true),'')
$$;
grant usage on schema public,auth,storage to authenticated,anon;
grant execute on function auth.uid(),auth.role() to authenticated,anon;
create table auth.users(id uuid primary key,raw_user_meta_data jsonb default '{}'::jsonb);
create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
create table storage.objects(id uuid primary key default gen_random_uuid(),bucket_id text,name text,owner uuid default auth.uid());
alter table storage.objects enable row level security;
"""]
tables = sorted({c['table_name'] for c in schema['columns']})
for table in tables:
    cols=[]
    for c in schema['columns']:
        if c['table_name'] != table:
            continue
        definition = ident(c['column_name'])+' '+c['udt_name']
        if c['column_default'] is not None:
            definition += ' default '+c['column_default']
        if c['is_nullable'] == 'NO':
            definition += ' not null'
        cols.append(definition)
    sql.append('create table public.'+ident(table)+'(\n  '+',\n  '.join(cols)+'\n);')
for c in sorted(schema['constraints'], key=lambda c:c['definition'].startswith('FOREIGN KEY')):
    sql.append('alter table public.'+ident(c['table'])+' add constraint '+ident(c['name'])+' '+c['definition']+';')
for entry in schema['rls']:
    if entry['enabled']:
        sql.append('alter table public.'+ident(entry['table'])+' enable row level security;')
    if entry['forced']:
        sql.append('alter table public.'+ident(entry['table'])+' force row level security;')
for function in schema['functions']:
    sql.append(function['definition'].rstrip(';')+';')
for trigger in schema['triggers']:
    sql.append(trigger['definition'].rstrip(';')+';')
for p in schema['policies']:
    statement='create policy '+ident(p['policyname'])+' on '+ident(p['schemaname'])+'.'+ident(p['tablename'])
    statement+=' as '+p['permissive']+' for '+p['cmd']+' to '+','.join('public' if role=='public' else ident(role) for role in p['roles'])
    if p['qual'] is not None:
        statement+=' using('+p['qual']+')'
    if p['with_check'] is not None:
        statement+=' with check('+p['with_check']+')'
    sql.append(statement+';')
for b in schema['buckets']:
    mime='null' if b['allowed_mime_types'] is None else 'array['+','.join(literal(x) for x in b['allowed_mime_types'])+']'
    sql.append('insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('+','.join([
        literal(b['id']),literal(b['id']),str(b['public']).lower(),str(b['file_size_limit']) if b['file_size_limit'] is not None else 'null',mime])+');')
realtime = schema['realtime'] or []
if realtime:
    sql.append('create publication supabase_realtime;')
    for r in realtime:
        sql.append('alter publication supabase_realtime add table '+ident(r['schemaname'])+'.'+ident(r['tablename'])+';')
sql.append('-- Model permissive legacy table grants to verify migration revocations.\ngrant select,insert,update,delete on all tables in schema public,storage to authenticated,anon;')
output=root/'tools/fixtures/supabase_export_20261014.sql'
output.parent.mkdir(parents=True,exist_ok=True)
output.write_text('\n\n'.join(sql)+'\n',encoding='utf-8')
print(f'Fixture: {len(tables)} public tables, {len(schema["policies"])} policies, {len(schema["functions"])} functions, {len(schema["triggers"])} triggers.')

