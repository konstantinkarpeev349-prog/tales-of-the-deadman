(() => {
  'use strict';
  const dashboard = document.querySelector('[data-archive-dashboard]');
  if (!dashboard) return;
  const style = document.createElement('link');
  style.rel = 'stylesheet';
  style.href = 'archive-profile-activity.css';
  document.head.append(style);
  const section = document.createElement('section');
  section.className = 'archive-personnel-activity';
  section.innerHTML = '<p class="eyebrow">Личное дело</p><h2>Активность сотрудника</h2><dl><div><dt>Прочитано</dt><dd data-stat="chapters">—</dd></div><div><dt>Изучено</dt><dd data-stat="documents">—</dd></div><div><dt>Просмотрено</dt><dd data-stat="dossiers">—</dd></div><div><dt>Время в Архиве</dt><dd data-stat="time">—</dd></div><div><dt>Награды</dt><dd data-stat="awards">—</dd></div></dl><p class="archive-activity-note" data-activity-note role="status"></p>';
  dashboard.after(section);
  const show = (key, value) => { section.querySelector(`[data-stat="${key}"]`).textContent = value; };
  const formatTime = seconds => {
    const minutes = Math.floor(Math.max(0, Number(seconds) || 0) / 60);
    if (minutes < 60) return `${minutes} мин`;
    return `${Math.floor(minutes / 60)} ч ${String(minutes % 60).padStart(2, '0')} мин`;
  };
  const readCodes = new Set(['READ_PROLOGUE', 'READ_CHAPTER_1', 'READ_CHAPTER_2', 'READ_CHAPTER_3']);
  const form = (number, one, few, many) => number % 100 >= 11 && number % 100 <= 14 ? many : number % 10 === 1 ? one : number % 10 >= 2 && number % 10 <= 4 ? few : many;
  const documentSlugs = new Set(['magic-basics', 'king-filk', 'morgeus', 'frauster-maizervin-feud', 'dokains-anatomy']);
  const load = async () => {
    try {
      const account = await TODMAuth.getAccount();
      if (!account.session) return;
      const client = TODMAuth.client;
      const [summary, definitions, reads, publicViews] = await Promise.all([
        client.rpc('archive_get_my_dashboard', { p_ledger_limit: 0 }),
        client.from('achievement_definitions').select('code').eq('is_active', true),
        client.from('content_reads').select('content_id,archive_content(slug)'),
        client.from('archive_public_dossier_views').select('path')
      ]);
      if (summary.error) throw summary.error;
      const data = summary.data || {};
      const achievements = data.achievements || [];
      const chapters = achievements.filter(item => readCodes.has(item.achievement_code)).length;
      show('chapters', `${chapters} ${form(chapters, 'часть', 'части', 'частей')}`);
      show('time', formatTime(data.progress?.active_seconds));
      if (!definitions.error) show('awards', `${achievements.length} / ${definitions.data.length}`);
      if (!reads.error) {
        const slugs = (reads.data || []).map(item => item.archive_content?.slug).filter(Boolean);
        const documents = new Set(slugs.filter(slug => documentSlugs.has(slug))).size;
        show('documents', `${documents} ${form(documents, 'документ', 'документа', 'документов')}`);
        if (!publicViews.error) {
          const dossiers = new Set(slugs.filter(slug => slug.startsWith('artifact-')));
          for (const item of publicViews.data || []) dossiers.add(item.path);
          show('dossiers', `${dossiers.size} досье`);
        }
      }
      if (publicViews.error) section.querySelector('[data-activity-note]').textContent = 'Статистика открытых досье появится после применения миграции 041.';
    } catch (error) {
      console.warn('Archive activity unavailable', error);
      section.querySelector('[data-activity-note]').textContent = 'Не удалось загрузить часть статистики. Попробуйте обновить страницу.';
    }
  };
  if (window.TODMAuth) load();
  else addEventListener('todm-auth-ready', load, { once: true });
})();
