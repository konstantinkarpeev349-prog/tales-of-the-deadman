(() => {
  'use strict';

  const root = document.querySelector('[data-archive-record]');
  if (!root) return;

  const esc = value => String(value ?? '').replace(/[&<>"']/g, char => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
  }[char]));
  const internalDocuments = new Set([
    'Archive_Morgeus.html',
    'Archive_Frauster_Maizervin.html'
  ]);
  const unsafeCharacters = /[\u0000-\u0020\u007f-\u009f\u00a0\u1680\u180e\u2000-\u200b\u2028\u2029\u202f\u205f\u3000\ufeff\\]/u;
  const encodedControls = /%(?:0[0-9a-f]|1[0-9a-f]|7f|c2%a0|e2%80%8[0-9a-f]|e2%80%a[89])/i;

  function safeRelatedHref(value) {
    if (typeof value !== 'string' || !value || unsafeCharacters.test(value) || encodedControls.test(value)) return null;

    const internal = value.match(/^([A-Za-z0-9_]+\.html)(#[A-Za-z0-9_-]+)?$/);
    if (internal && internalDocuments.has(internal[1])) return { href: value, external: false };

    // Require a literal HTTPS scheme. Encoded, relative, protocol-relative and
    // browser-normalized variants must not become executable or off-site links.
    if (!value.startsWith('https://')) return null;
    try {
      const url = new URL(value);
      if (url.protocol !== 'https:' || !url.hostname || url.username || url.password) return null;
      return { href: url.href, external: true };
    } catch {
      return null;
    }
  }

  const block = section => `<section class="archive-doc-section ${esc(section.tone || '')}"><div><p class="eyebrow">${esc(section.eyebrow)}</p><h2>${esc(section.title)}</h2></div><div class="archive-doc-copy">${(section.paragraphs || []).map(paragraph => `<p>${esc(paragraph)}</p>`).join('')}${section.emphasis ? `<strong class="archive-emphasis">${esc(section.emphasis)}</strong>` : ''}</div></section>`;
  const related = item => {
    if (!item) return '';
    const link = safeRelatedHref(item.href);
    const label = `${esc(item.title)} →`;
    return `<aside class="archive-related"><p class="eyebrow">Связанный документ</p>${link ? `<a href="${esc(link.href)}"${link.external ? ' rel="noopener noreferrer"' : ''}>${label}</a>` : `<span>${label}</span>`}</aside>`;
  };

  const init = async () => {
    try {
      const account = await TODMArchive.account();
      if (!account.session || !TODMArchive.can(account.access, 1)) {
        return TODMArchive.gate(root, 'I', account, location.pathname.split('/').pop());
      }
      const { data, error } = await TODMAuth.client.from('archive_content')
        .select('id,body').eq('slug', root.dataset.slug).maybeSingle();
      if (error) throw error;
      if (!data) {
        root.innerHTML = '<section class="archive-placeholder"><nav class="archive-breadcrumbs"><a href="Archive.html">Архив</a><span>→</span><a href="Archive_Level_I.html">Уровень I</a></nav><h1>Запись не активирована</h1><p>Защищённый документ подготовлен локально, но соответствующая миграция Supabase ещё не применена.</p><a class="archive-doc-back" href="Archive_Level_I.html">← НАЗАД К ДОКУМЕНТАМ</a></section>';
        return;
      }
      const body = data.body || {};
      const timeline = body.timeline || [];
      root.innerHTML = `<section class="archive-hero archive-doc-hero"><img src="${esc(root.dataset.hero)}" alt="${esc(root.dataset.heroAlt)}"><nav class="archive-breadcrumbs"><a href="Archive.html">Архив</a><span>→</span><a href="Archive_Level_I.html">Уровень I</a><span>→</span><span>${esc(body.title)}</span></nav><p class="eyebrow">${esc(body.type)} · ${esc(root.dataset.code)}</p><h1>${esc(body.title)}</h1><p>${esc(body.subtitle)}</p><a class="archive-doc-back" href="Archive_Level_I.html">← НАЗАД К ДОКУМЕНТАМ</a></section><article class="archive-doc-body">${body.stat ? `<section class="archive-stat"><strong>${esc(body.stat.value)}</strong><div><p class="eyebrow">Архивная сводка</p><h2>${esc(body.stat.title)}</h2><p>${esc(body.stat.text)}</p></div></section>` : ''}${(body.sections || []).map(block).join('')}${body.contrast ? `<section class="archive-contrast"><div><span>Общепринято</span><p>${esc(body.contrast.common)}</p></div><div><span>Архивные данные</span><p>${esc(body.contrast.archive)}</p></div></section>` : ''}${timeline.length ? `<section class="archive-timeline"><p class="eyebrow">Хронология события</p><h2>Последовательность, разрушившая доверие</h2><ol>${timeline.map(entry => `<li>${esc(entry)}</li>`).join('')}</ol></section>` : ''}${body.closing ? `<blockquote class="archive-closing">${esc(body.closing)}</blockquote>` : ''}${related(body.related)}<a class="archive-doc-back" href="Archive_Level_I.html">← НАЗАД К ДОКУМЕНТАМ</a></article>`;
      await TODMAuth.client.from('content_reads').upsert({
        user_id: account.user.id,
        content_id: data.id,
        last_opened_at: new Date().toISOString()
      }, { onConflict: 'user_id,content_id' });
    } catch (error) {
      console.error(error);
      root.innerHTML = '<section class="archive-gate"><h1>Архив временно недоступен</h1><p>Не удалось загрузить защищённую запись.</p></section>';
    }
  };
  init();
})();
