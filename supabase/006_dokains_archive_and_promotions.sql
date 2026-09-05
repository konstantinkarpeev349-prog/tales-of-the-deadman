-- Apply after schema.sql and 002_staff_ranks.sql.
begin;

create table if not exists public.rank_promotion_notifications (
  user_id uuid primary key references auth.users(id) on delete cascade,
  previous_level smallint not null,
  new_level smallint not null,
  promoted_at timestamptz not null default now(),
  seen_at timestamptz,
  check (new_level > previous_level)
);

alter table public.rank_promotion_notifications enable row level security;
drop policy if exists "read own rank promotion" on public.rank_promotion_notifications;
create policy "read own rank promotion" on public.rank_promotion_notifications
for select to authenticated using (auth.uid()=user_id);
drop policy if exists "acknowledge own rank promotion" on public.rank_promotion_notifications;
create policy "acknowledge own rank promotion" on public.rank_promotion_notifications
for update to authenticated using (auth.uid()=user_id)
with check (auth.uid()=user_id);
grant select,update(seen_at) on public.rank_promotion_notifications to authenticated;

create or replace function public.record_rank_promotion()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  if new.archive_level > old.archive_level then
    insert into public.rank_promotion_notifications(user_id,previous_level,new_level,promoted_at,seen_at)
    values(new.user_id,old.archive_level,new.archive_level,now(),null)
    on conflict(user_id) do update set
      previous_level=least(public.rank_promotion_notifications.previous_level,excluded.previous_level),
      new_level=excluded.new_level,
      promoted_at=excluded.promoted_at,
      seen_at=null;
  end if;
  return new;
end;$$;

drop trigger if exists notify_rank_promotion on public.account_access;
create trigger notify_rank_promotion after update of archive_level on public.account_access
for each row when (new.archive_level > old.archive_level)
execute function public.record_rank_promotion();

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('archive-media','archive-media',false,10485760,array['image/jpeg','image/png','image/webp'])
on conflict(id) do update set public=false,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;

drop policy if exists "read level one archive media" on storage.objects;
create or replace function public.can_read_archive(p_level smallint)
returns boolean language sql stable security definer set search_path='' as $$
  select exists(
    select 1 from public.account_access a
    where a.user_id=auth.uid() and not a.is_banned
      and (a.full_access or a.archive_level>=p_level)
  );
$$;
revoke all on function public.can_read_archive(smallint) from public,anon;
grant execute on function public.can_read_archive(smallint) to authenticated;
create policy "read level one archive media" on storage.objects
for select to authenticated using (
  bucket_id='archive-media' and public.can_read_archive(1::smallint)
);

drop function if exists public.staff_list_users(text,integer);
create function public.staff_list_users(p_search text default '',p_offset integer default 0)
returns table(user_id uuid,display_name text,archive_level smallint,protected boolean,is_todm_team boolean,is_author boolean,updated_at timestamptz)
language plpgsql security definer set search_path='' as $$
begin
  if not exists(select 1 from public.account_access a where a.user_id=auth.uid() and not a.is_banned and (a.is_admin or a.is_todm_team)) then
    raise exception 'Доступ только для TODM' using errcode='42501';
  end if;
  return query select a.user_id,coalesce(p.display_name::text,'Читатель'),a.archive_level,
    (a.is_admin or a.is_author or a.is_todm_team or a.archive_level>=4),a.is_todm_team,a.is_author,a.updated_at
  from public.account_access a left join public.profiles p on p.user_id=a.user_id
  where coalesce(p.display_name::text,'') ilike '%'||left(coalesce(p_search,''),100)||'%'
  order by p.created_at desc,a.user_id limit 50 offset greatest(coalesce(p_offset,0),0);
end;$$;
revoke all on function public.staff_list_users(text,integer) from public,anon;
grant execute on function public.staff_list_users(text,integer) to authenticated;

insert into public.archive_content(slug,title,body,registration_required,required_archive_level,published)
values(
  'dokains-anatomy',
  'Устройство докаинов',
  jsonb_build_object(
    'title','Докаины',
    'lead','Тёмные энергетические существа, рождённые из энергии вне нашего мира.',
    'image_path','dokains/dokains-archive-infographic.png',
    'sections',jsonb_build_array(
      jsonb_build_object('eyebrow','01 · Что такое докаины','title','Аномалия во вселенной','paragraphs',jsonb_build_array('Докаины — тёмные энергетические существа. Они являются сгустками энергии и существуют во вселенной как аномалия.','Они появляются поодиночке. Их тело состоит из тёмной энергии: оно абсолютно чёрное, окружено струящейся энергетической дымкой, а белые глаза лишены зрачков.')),
      jsonb_build_object('eyebrow','02 · Происхождение','title','Эксперимент с Альфой','paragraphs',jsonb_build_array('Во время событий первого тома несколько докаинов были намеренно помещены вместе в одну клетку с Альфой. Затем их высадили на необитаемую планету в рамках эксперимента.','Результатом эксперимента стали события, связанные с появлением известной нам популяции докаинов.')),
      jsonb_build_object('eyebrow','03 · Устройство тела','title','Энергия, удерживаемая ядром','paragraphs',jsonb_build_array('Очертания тела докаина могут быть нестабильными и искажаться. Докаины способны трансформировать конечности.','Они являются энергетическими существами, а не людьми, и физически изначально значительно сильнее обычных людей.')),
      jsonb_build_object('eyebrow','04 · Ядро докаина','title','Источник сущности и формы','paragraphs',jsonb_build_array('Внутри каждого докаина находится ядро. Это одна из важнейших частей существа, определяющая особенности его существования.','У обычного докаина ядро относительно стабильное и не обладает экстремально высокой плотностью.')),
      jsonb_build_object('eyebrow','05 · Изменение параметров','title','Воздействие на состояние','paragraphs',jsonb_build_array('Изменение плотности и стабильности может влиять на количество доступной энергии, физическое состояние докаина, способность переносить изменения и особенности управления энергией.')),
      jsonb_build_object('eyebrow','06 · Трансформация конечностей','title','Непостоянная форма','paragraphs',jsonb_build_array('Энергетическая природа позволяет докаинам изменять форму конечностей. Архив фиксирует это как одно из основных проявлений управления собственным телом.'))
    )
  ),true,1,true
)
on conflict(slug) do update set title=excluded.title,body=excluded.body,registration_required=true,required_archive_level=1,published=true,updated_at=now();

commit;

-- Upload the supplied PNG through the Supabase dashboard to the private bucket:
-- bucket: archive-media
-- object path: dokains/dokains-archive-infographic.png
