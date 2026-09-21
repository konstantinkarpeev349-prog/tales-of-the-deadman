-- Publish canonical free-reading text imported from the author-owned Author.Today work.
begin;
update public.archive_reading_content set title='Пролог',body='{"source":{"work_id":465885,"chapter_id":4346840,"platform":"Author.Today"}}'::jsonb,status='PUBLISHED',published=true,minimum_active_seconds=540,updated_at=now() where content_key='prologue';
update public.archive_reading_content set title='Глава 1',body='{"source":{"work_id":465885,"chapter_id":4346840,"platform":"Author.Today"}}'::jsonb,status='PUBLISHED',published=true,minimum_active_seconds=1440,updated_at=now() where content_key='chapter-1';
update public.archive_reading_content set title='Глава 2',body='{"source":{"work_id":465885,"chapter_id":4363431,"platform":"Author.Today"}}'::jsonb,status='PUBLISHED',published=true,minimum_active_seconds=1800,updated_at=now() where content_key='chapter-2';
update public.archive_reading_content set title='Глава 3',body='{"source":{"work_id":465885,"chapter_id":4455277,"platform":"Author.Today"}}'::jsonb,status='PUBLISHED',published=true,minimum_active_seconds=1800,updated_at=now() where content_key='chapter-3';
update public.archive_rules set value=jsonb_set(value,'{enabled}','true'::jsonb,true) where rule_key='reading_verification' and jsonb_typeof(value)='object';
commit;
