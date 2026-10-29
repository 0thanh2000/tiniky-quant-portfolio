"""Generate the initial SQL Editor installer from the ordered migrations."""
from pathlib import Path
import re

root=Path(__file__).resolve().parents[1]
parts=['''-- INITIAL INSTALL ONLY, for the schema exported on 2026-10-14.
-- First run KIEM_TRA_TRUOC.sql; all issue_count values must be zero.
-- This replaces running the four migrations individually: choose ONE route.
-- One transaction: a failure leaves the database unchanged.
begin;
do $$ begin
  if to_regclass('public.app_calls') is not null or to_regclass('public.app_upload_events') is not null
     or to_regclass('public.app_notification_claims') is not null then
    raise exception 'Bản cài đã được chạy một phần hoặc toàn bộ. Không chạy lại INSTALLER; kiểm tra migration đã áp dụng trước.';
  end if;
end $$;
''']
for name in ['202610130001_social_features.sql','202610130002_upload_limits.sql',
             '202610130003_notification_limits.sql','202610140004_schema_alignment.sql']:
    source=(root/'supabase/migrations'/name).read_text()
    source=re.sub(r'^begin;\s*','',source,count=1,flags=re.M)
    source=re.sub(r'^commit;\s*$','',source,count=1,flags=re.M)
    parts.append('-- '+name+'\n'+source)
parts.append("notify pgrst,'reload schema';\ncommit;\n")
(root/'supabase/INSTALLER_SQL_EDITOR.sql').write_text('\n'.join(parts))
print('Installer built from four migrations in one transaction.')
