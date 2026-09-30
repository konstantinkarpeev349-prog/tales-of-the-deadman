(() => {
  'use strict';
  const wrap = document.querySelector('.archive-wrap');
  if (!wrap || !window.TODMDossiers) return;
  const panel = document.createElement('section');
  panel.className = 'archive-random-panel';
  panel.innerHTML = '<p class="eyebrow">Случайное досье</p><h2>Позвольте Архиву выбрать</h2><p>Архив содержит множество материалов о мире TODM. Не знаете, с чего продолжить изучение? Позвольте Архиву выбрать материал самостоятельно.</p><button type="button" data-random-dossier>Открыть случайное досье</button><p class="archive-random-status" data-random-status role="status" aria-live="polite"></p>';
  wrap.append(panel);
  const button = panel.querySelector('[data-random-dossier]');
  const status = panel.querySelector('[data-random-status]');
  button.addEventListener('click', async () => {
    button.disabled = true;
    status.textContent = 'Архив выбирает материал...';
    try {
      const choices = [...TODMDossiers.publicDossiers];
      if (window.TODMAuth) {
        const account = await TODMAuth.getAccount();
        if (account.session && account.access && !account.access.is_banned) {
          // RLS returns only published rows this account may actually read.
          const { data, error } = await TODMAuth.client.from('archive_content')
            .select('slug').in('slug', Object.keys(TODMDossiers.restricted));
          if (error) throw error;
          for (const row of data || []) {
            const path = TODMDossiers.restricted[row.slug];
            if (path) choices.push(path);
          }
        }
      }
      const array = new Uint32Array(1);
      crypto.getRandomValues(array);
      const target = choices[array[0] % choices.length];
      if (!target) throw new Error('В Архиве нет доступных материалов');
      if (!matchMedia('(prefers-reduced-motion: reduce)').matches) {
        await new Promise(resolve => setTimeout(resolve, 600));
      }
      location.assign(target);
    } catch (error) {
      console.error('Random dossier unavailable', error);
      status.textContent = 'Не удалось выбрать материал. Попробуйте ещё раз.';
      button.disabled = false;
    }
  });
})();
