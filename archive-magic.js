(() => {
  'use strict';
  const root = document.querySelector('[data-magic-root]');
  if (!root) return;

  const escapeHtml = value => String(value ?? '').replace(/[&<>"']/g, char => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
  }[char]));
  const back = '<a class="archive-doc-back" href="Archive_Level_I.html">← НАЗАД К ДОКУМЕНТАМ</a>';
  const section = entry => `<section class="archive-doc-section"><div><p class="eyebrow">${escapeHtml(entry.eyebrow)}</p><h2>${escapeHtml(entry.title)}</h2></div><div class="archive-doc-copy">${(entry.paragraphs || []).map(paragraph => `<p>${escapeHtml(paragraph)}</p>`).join('')}</div></section>`;

  async function init() {
    try {
      const account = await TODMArchive.account();
      if (!account.session || !TODMArchive.can(account.access, 1)) {
        TODMArchive.gate(root, 'I', account, 'Archive_Magic.html');
        return;
      }

      const { data, error } = await TODMAuth.client.from('archive_content')
        .select('id,body').eq('slug', 'magic-basics').maybeSingle();
      if (error) throw error;
      if (!data?.body) {
        root.innerHTML = '<section class="archive-placeholder"><h1>Запись не активирована</h1><p>Документ ожидает публикации в защищённом Архиве.</p>' + back + '</section>';
        return;
      }

      const body = data.body;
      root.innerHTML = `<section class="archive-hero archive-doc-hero magic-hero">
        <img src="images/characters-archive-texture.jpg" alt="" aria-hidden="true">
        <nav class="archive-breadcrumbs" aria-label="Путь по Архиву"><a href="Archive.html">Архив</a><span>→</span><a href="Archive_Level_I.html">Рассекреченные документы</a><span>→</span><span>Что такое магия</span></nav>
        <p class="eyebrow">Документ 01 · допуск I · MAG–01</p>
        <h1>${escapeHtml(body.title)}</h1>
        <p>${escapeHtml(body.subtitle)}</p>
        ${back}
      </section>
      <article class="archive-doc-body magic-document">
        ${section(body.introduction)}
        <figure class="magic-archive-plate">
          <a href="images/magic-neuronexus-schema.png" target="_blank" rel="noopener" aria-label="Открыть схему нейронекса в полном размере">
            <img src="images/magic-neuronexus-schema.png" alt="Архивная иллюстрация строения нейронекса и видов человеческой магии" loading="lazy">
          </a>
          <figcaption>Архивная схема нейронекса · нажмите, чтобы открыть крупнее</figcaption>
        </figure>
        <section class="magic-principle" aria-labelledby="magic-principle-title">
          <p class="eyebrow">Базовый принцип</p>
          <h2 id="magic-principle-title">Как возникает магическое явление</h2>
          <ol class="magic-flow">${(body.flow || []).map(step => `<li>${escapeHtml(step)}</li>`).join('')}</ol>
          <p>${escapeHtml(body.principle)}</p>
        </section>
        ${(body.sections || []).map(section).join('')}
        <section class="magic-warning" aria-labelledby="magic-warning-title">
          <p class="eyebrow">Предупреждение Архива</p>
          <h2 id="magic-warning-title">Критическое истощение</h2>
          <p>${escapeHtml(body.warning)}</p>
        </section>
        <aside class="magic-note">
          <p class="eyebrow">Примечание Архива</p>
          <p>${escapeHtml(body.note)}</p>
        </aside>
        ${back}
      </article>`;

      const read = await TODMAuth.client.from('content_reads').upsert({
        user_id: account.user.id,
        content_id: data.id,
        last_opened_at: new Date().toISOString()
      }, { onConflict: 'user_id,content_id' });
      if (read.error) console.warn('Archive reading marker unavailable', read.error);
    } catch (error) {
      console.error(error);
      root.innerHTML = '<section class="archive-gate"><h1>Архив временно недоступен</h1><p>Не удалось загрузить защищённый документ.</p>' + back + '</section>';
    }
  }

  init();
})();
