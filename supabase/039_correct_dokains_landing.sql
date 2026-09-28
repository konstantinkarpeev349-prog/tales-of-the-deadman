-- Correct only the Archive I account of the dokains' landing.
begin;

update public.archive_content
set body = jsonb_set(
  body,
  '{sections,1,paragraphs,0}',
  to_jsonb('Во время событий первого тома несколько докаинов были намеренно помещены вместе в одну клетку с Альфой. Затем их высадили на Антамариду — мир, в котором происходят события первого тома «Сказок Мертвеца».'::text)
), updated_at = now()
where slug = 'dokains-anatomy'
  and body #>> '{sections,1,paragraphs,0}' =
    'Во время событий первого тома несколько докаинов были намеренно помещены вместе в одну клетку с Альфой. Затем их высадили на необитаемую планету в рамках эксперимента.';

commit;
