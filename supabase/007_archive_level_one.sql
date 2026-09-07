-- Apply after 006_dokains_archive_and_promotions.sql.
begin;

insert into public.archive_content(slug,title,body,registration_required,required_archive_level,published)
values(
  'king-filk',
  'Король Филк',
  jsonb_build_object(
    'title','Король Филк',
    'lead','Нынешний Филк сильно отличается от человека, которым он был до Великой войны драконов.',
    'sections',jsonb_build_array(
      jsonb_build_object('eyebrow','I · До войны','title','Король, которого помнили другим','paragraphs',jsonb_build_array('В прошлом Филк был достойным и деятельным королём. Он не прятался за стенами дворца и принял участие в Великой войне драконов.','Рядом с ним была семья: жена и два сына. Позднее любые сведения о них исчезнут из официальной истории.')),
      jsonb_build_object('eyebrow','II · Союз','title','Дракон на стороне людей','paragraphs',jsonb_build_array('Во время войны Филк заключил союз с одним из драконов. Тот сражался вместе с королём против остальных драконов.','Союз давал людям силу и надежду, но оказался лишь отсрочкой перед личной катастрофой Филка.')),
      jsonb_build_object('eyebrow','III · Понтикан','title','Предательство и осада','paragraphs',jsonb_build_array('Дракон предал Филка. Была осаждена крепость Понтикан — место, где находилась семья короля.','Жена Филка и оба его сына погибли. Эта потеря сломила человека, которым он был прежде.')),
      jsonb_build_object('eyebrow','IV · После победы','title','История без семьи','paragraphs',jsonb_build_array('После войны Филк запретил любые упоминания о том, что у него была семья. Сведения о жене и сыновьях исчезли из официальной истории.','Война закончилась победой людей. Последнего дракона убил капитан Гас. Филк сохранил корону и оказался на стороне победителей, несмотря на личную катастрофу.'))
    ),
    'closing','Он потерял практически всё. Однако он победил.'
  ),true,1,true
)
on conflict(slug) do update set title=excluded.title,body=excluded.body,registration_required=true,required_archive_level=1,published=true,updated_at=now();

commit;
