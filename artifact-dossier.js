(() => {
  'use strict';
  const root = document.querySelector('[data-artifact-dossier]');
  if (!root) return;
  const entries = {
    will: { slug: 'artifact-will', code: '01', level: 0, tone: 'will' },
    harvest: { slug: 'artifact-harvest', code: '02', level: 0, tone: 'harvest' },
    elements: { slug: 'artifact-elements', code: '03', level: 0, tone: 'elements' },
    wishes: { slug: 'artifact-wishes', code: '04', level: 1, tone: 'wishes' },
    dragons: { slug: 'artifact-dragons', code: '05', level: 0, tone: 'dragons' },
    frauster: { slug: 'artifact-frauster-crown', code: '06', level: 0, tone: 'frauster' },
    galdvin: { slug: 'artifact-galdvin-crown', code: '07', level: 1, tone: 'galdvin' }
  };
  const entry = entries[root.dataset.artifactDossier];
  if (!entry) return;
  const esc = value => String(value ?? '').replace(/[&<>"']/g, char => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[char]));
  const back = '<a class="artifact-back" href="Artifacts_Tom_I.html">← НАЗАД К АРТЕФАКТАМ</a>';
  const paragraphs = values => (values || []).map(value => `<p>${esc(value)}</p>`).join('');
  async function init() {
    try {
      const account = await TODMArchive.account();
      if (!account.session || !TODMArchive.can(account.access, entry.level)) {
        TODMArchive.gate(root, entry.level === 1 ? 'I' : '0', account, location.pathname.split('/').pop());
        root.insertAdjacentHTML('beforeend', `<div class="artifact-gate-back">${back}</div>`);
        return;
      }
      // The browser receives dossier text only after archive_content RLS approves this row.
      const { data, error } = await TODMAuth.client.from('archive_content')
        .select('id,body').eq('slug', entry.slug).maybeSingle();
      if (error) throw error;
      if (!data?.body) {
        root.innerHTML = `<section class="archive-gate"><h1>Запись ещё не активирована</h1><p>Досье ожидает применения миграции Supabase.</p>${back}</section>`;
        return;
      }
      const body = data.body;
      root.innerHTML = `<article class="artifact-dossier artifact-dossier--${entry.tone}"><header class="artifact-dossier__header"><nav class="artifact-breadcrumbs" aria-label="Путь к досье"><a href="Tom_I.html">Том I</a><span>→</span><a href="Artifacts_Tom_I.html">Артефакты</a><span>→</span><span>${esc(body.title)}</span></nav><p class="eyebrow">Досье ${entry.code} · ${entry.level ? 'Архив I' : 'Том I'}</p><h1>${esc(body.title)}</h1><p class="artifact-dossier__lead">${esc(body.summary)}</p>${back}</header><div class="artifact-dossier__content"><figure class="artifact-dossier__visual">${entry.image ? `<img src="${entry.image}" alt="${esc(body.title)}" loading="eager">` : `<div aria-hidden="true" class="artifact-dossier__plate"><span>${entry.code}</span><strong>${esc(body.title)}</strong></div>`}<figcaption>${entry.image ? 'Архивное изображение' : 'Иллюстрация артефакта пока не представлена в Архиве'}</figcaption></figure><div class="artifact-dossier__text"><dl class="artifact-facts"><div><dt>Тип</dt><dd>${esc(body.type)}</dd></div><div><dt>Связь</dt><dd>${esc(body.owner)}</dd></div><div><dt>Статус</dt><dd>${esc(body.status || 'Известен по Тому I')}</dd></div></dl><section><h2>Описание</h2>${paragraphs(body.description)}</section><section><h2>Известные свойства</h2><ul>${(body.properties || []).map(value => `<li>${esc(value)}</li>`).join('')}</ul></section>${body.origin?.length ? `<section><h2>Происхождение и свидетельства</h2>${paragraphs(body.origin)}</section>` : ''}${body.note ? `<aside class="artifact-dossier__note"><p class="eyebrow">Примечание Архива</p><p>${esc(body.note)}</p></aside>` : ''}${back}</div></div></article>`;
      const read = await TODMAuth.client.from('content_reads').upsert({
        user_id: account.user.id, content_id: data.id, last_opened_at: new Date().toISOString()
      }, { onConflict: 'user_id,content_id' });
      if (read.error) console.warn('Artifact reading marker unavailable', read.error);
    } catch (error) {
      console.error(error);
      root.innerHTML = `<section class="archive-gate"><h1>Архив временно недоступен</h1><p>Не удалось загрузить досье.</p>${back}</section>`;
    }
  }
  init();
})();
