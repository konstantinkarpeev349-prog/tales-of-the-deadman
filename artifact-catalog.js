(() => {
  'use strict';
  const root = document.querySelector('[data-artifact-catalog]');
  if (!root) return;
  const items = [
    { n: '01', title: 'Меч Воли', type: 'Магическое оружие · палаш', owner: 'Дан', description: 'Широкий обсидиановый палаш, связанный с внутренней силой владельца.', file: 'Artifact_Will.html', tone: 'will' },
    { n: '02', title: 'Меч Жатвы', type: 'Магическое оружие', owner: 'Форелл / Дариус', description: 'Раздвоенный клинок с фиолетовым кристаллом; извлекает жизненную силу через ранение.', file: 'Artifact_Harvest.html', tone: 'harvest' },
    { n: '03', title: 'Посох стихий', type: 'Магический артефакт · ограничитель', owner: 'Моргеус', description: 'Вращающиеся вокруг посоха камни помогают сдерживать огромную силу Моргеуса.', file: 'Artifact_Elements.html', tone: 'elements' },
    { n: '04', title: 'Книга желаний', type: 'Магическая книга', owner: 'Местонахождение неизвестно', description: 'Древнее упоминание об артефакте, способном исполнить желание.', file: 'Artifact_Wishes.html', tone: 'wishes', level: 1 },
    { n: '05', title: 'Меч драконов', type: 'Магическое оружие · катана', owner: 'Лиенна', description: 'Длинная катана, связанная с огненной силой и человеческим обликом Лиенны.', file: 'Artifact_Dragons.html', tone: 'dragons' },
    { n: '06', title: 'Корона Фраустера', type: 'Королевская регалия', owner: 'Короли Фраустера · Филк', description: '«Корона мёртвых» позволяет королю обратиться к умершим предшественникам.', file: 'Artifact_Frauster_Crown.html', tone: 'frauster' },
    { n: '07', title: 'Корона короля Галдвина', type: 'Королевская регалия', owner: 'Галдвин / Майзервин', description: 'Неполное досье: подтверждён холодный отклик при контакте с короной.', file: 'Artifact_Galdvin_Crown.html', tone: 'galdvin', level: 1 }
  ];
  const esc = value => String(value).replace(/[&<>"']/g, char => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[char]));
  async function init() {
    try {
      const account = await TODMArchive.account();
      if (!account.session || !account.access || account.access.is_banned) {
        TODMArchive.gate(root, 0, account, 'Artifacts_Tom_I.html');
        return;
      }
      const hasLevelOne = TODMArchive.can(account.access, 1);
      root.classList.remove('archive-loading');
      root.innerHTML = `<section class="artifact-catalog" aria-labelledby="artifact-catalog-title"><div class="artifact-catalog__head"><p class="eyebrow">Опись 01–07</p><h2 id="artifact-catalog-title">Архив артефактов</h2><p>Сведения ограничены событиями первого тома. Отдельные записи доступны только с допуском Архива I.</p></div><div class="artifact-grid">${items.map(item => {
        const locked = item.level && !hasLevelOne;
        return `<article class="artifact-card artifact-card--${item.tone}${locked ? ' artifact-card--locked' : ''}"><div class="artifact-card__visual">${item.image ? `<img src="${item.image}" alt="${esc(item.title)}" loading="lazy">` : `<span aria-hidden="true">${item.n}</span>`}</div><div class="artifact-card__body"><p class="artifact-card__index">Досье ${item.n} / Том I</p><h3>${esc(item.title)}</h3><dl><div><dt>Тип</dt><dd>${esc(item.type)}</dd></div><div><dt>Связь</dt><dd>${esc(item.owner)}</dd></div></dl><p>${esc(item.description)}</p><span class="artifact-card__status">${locked ? 'ТРЕБУЕТСЯ ДОПУСК АРХИВА I' : item.level ? 'АРХИВ I · ДОСТУП ОТКРЫТ' : 'ДОСТУПНО ПОСЛЕ ВХОДА'}</span><a class="artifact-card__link" href="${item.file}">${locked ? 'ПРОВЕРИТЬ ДОПУСК' : 'ОТКРЫТЬ ДОСЬЕ'} <span aria-hidden="true">↗</span></a></div></article>`;
      }).join('')}</div></section>`;
    } catch (error) {
      console.error(error);
      root.innerHTML = '<section class="archive-gate"><h2>Архив временно недоступен</h2><p>Не удалось проверить доступ к каталогу.</p></section>';
    }
  }
  init();
})();
