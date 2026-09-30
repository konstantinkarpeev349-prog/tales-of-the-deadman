(() => {
  'use strict';

  const page = location.pathname.split('/').pop() || 'index.html';
  const sections = [
    ['Книги', 'Reed.html', /^(index|Reed|Tom_I|Pers_Tom_I|Factions_Tom_I|World_Tom_I|Artifacts_Tom_I|Free_Reading|Tome_III|Tom_II|Tome_II_)/],
    ['Архив', 'Archive.html', /^(Archive|Dokains_Archive)/],
    ['TODM Games', 'TODM_Game_First.html', /^TODM_Game/],
    ['Общение', 'Community.html', /^(Community|Chat|FactionChat|Messages|Dialog)/],
    ['О проекте', 'Project.html', /^(Project|Command|Kontakt|Support|Details|Privacy|Terms)/],
    ['Магазин', 'Shop.html', /^Shop/]
  ];

  const links = sections.map(([label, href, pattern]) => {
    const current = pattern.test(page);
    const kind = href === 'Community.html' ? 'community-link' : href === 'Archive.html' ? 'archive-link' : '';
    return `<a href="${href}"${kind ? ` class="${kind}${current ? ' active' : ''}"` : current ? ' class="active"' : ''}${current ? ' aria-current="page"' : ''}>${label}</a>`;
  }).join('') + '<a class="account-link" href="Account.html">Кабинет</a>';

  const footer = `<div class="todm-footer-inner">
    <div class="todm-footer-main">
      <div class="todm-footer-intro"><a class="todm-footer-brand" href="index.html">TODM <span>Сказки Мертвеца</span></a><p>Шесть историй одного мира. Архив сохраняет то, что нельзя забыть.</p></div>
      <div><h2>Исследовать</h2><a href="Reed.html">Книги</a><a href="Archive.html">Архив</a><a href="TODM_Game_First.html">TODM Games</a><a href="Community.html">Общение</a></div>
      <div><h2>Проект</h2><a href="Project.html">О проекте</a><a href="Command.html">Команда</a><a href="Shop.html">Магазин</a><a href="Support.html">Поддержать</a></div>
      <div><h2>Связаться</h2><a href="Kontakt.html">Контакты</a><a href="https://t.me/talesofthedeadman2" target="_blank" rel="noopener noreferrer">Telegram</a><a href="https://author.today/u/konstantinkarpeev349" target="_blank" rel="noopener noreferrer">Author.Today</a></div>
    </div>
    <div class="todm-footer-bottom"><span>© <span data-year></span> Сказки Мертвеца</span><span>Истории тех, кто попытался изменить мир.</span><a href="Details.html">Реквизиты</a></div>
  </div>`;

  function setupHeader(header) {
    if (header.dataset.todmShellReady) return;
    header.dataset.todmShellReady = 'true';
    header.classList.add('todm-global-header');

    let inner = header.querySelector('.header-inner, .shop-nav');
    if (!inner) {
      inner = document.createElement('div');
      inner.className = 'header-inner';
      while (header.firstChild) inner.append(header.firstChild);
      header.append(inner);
    }
    inner.classList.add('todm-global-inner');

    let brand = inner.querySelector('.brand, .shop-brand, .game-brand');
    if (!brand) {
      brand = document.createElement('a');
      brand.href = 'index.html';
      inner.prepend(brand);
    }
    brand.classList.add('todm-global-brand');
    brand.href = 'index.html';
    brand.setAttribute('aria-label', 'Сказки Мертвеца — главная');
    brand.innerHTML = '<span class="todm-brand-mark">TODM</span><span class="todm-brand-name">Сказки Мертвеца</span>';

    let nav = inner.querySelector('.site-nav, .shop-links, .game-nav');
    if (!nav) {
      nav = document.createElement('nav');
      inner.append(nav);
    }
    nav.classList.add('todm-global-nav');
    nav.id = nav.id || 'site-nav';
    nav.setAttribute('aria-label', 'Основная навигация');
    nav.dataset.nav = '';
    nav.innerHTML = links;

    let toggle = inner.querySelector('.menu-toggle');
    if (!toggle) {
      toggle = document.createElement('button');
      toggle.type = 'button';
      toggle.className = 'menu-toggle todm-global-toggle';
      toggle.innerHTML = '<span>Меню</span><i aria-hidden="true"></i>';
      inner.insertBefore(toggle, nav);
      toggle.addEventListener('click', () => {
        const open = header.classList.toggle('open');
        document.body.classList.toggle('menu-open', open);
        toggle.setAttribute('aria-expanded', String(open));
      });
    }
    toggle.classList.add('todm-global-toggle');
    toggle.setAttribute('aria-label', 'Открыть меню');
    toggle.setAttribute('aria-controls', nav.id);
    toggle.setAttribute('aria-expanded', 'false');
    if (toggle.hasAttribute('data-menu')) {
      toggle.addEventListener('click', () => {
        const open = header.classList.toggle('open');
        document.body.classList.toggle('menu-open', open);
        toggle.setAttribute('aria-expanded', String(open));
      });
    }

    nav.addEventListener('click', event => {
      if (!event.target.closest('a')) return;
      header.classList.remove('open');
      document.body.classList.remove('menu-open');
      toggle.setAttribute('aria-expanded', 'false');
    });

    if (window.TODMAuth) window.dispatchEvent(new Event('todm-auth-change'));
  }

  function setupFooter(node) {
    if (node.dataset.todmShellReady) return;
    node.dataset.todmShellReady = 'true';
    node.classList.add('todm-global-footer');
    node.innerHTML = footer;
    node.querySelectorAll('[data-year]').forEach(year => { year.textContent = new Date().getFullYear(); });
  }

  function setupPolish() {
    const pageKinds = /^(index|Reed|Tom_I|Pers_Tom_I|Factions_Tom_I|World_Tom_I|Locations_Tom_I|Artifacts_Tom_I|Project|Shop|TODM_Game_First|Archive|Dokains_Archive)/;
    if (!pageKinds.test(page) || page === 'Archive_I_Trial.html') return;
    document.body.classList.add('todm-polish');

    const reduced = matchMedia('(prefers-reduced-motion: reduce)').matches;
    const selector = '.faction-card, .location-card, .archive-card, .archive-level, .shop-page .card, .archive-related__grid > a';
    const observer = !reduced && 'IntersectionObserver' in window
      ? new IntersectionObserver((entries, active) => entries.forEach(entry => {
          if (!entry.isIntersecting) return;
          entry.target.classList.add('todm-polish-visible');
          active.unobserve(entry.target);
        }), { threshold: .04, rootMargin: '0px 0px -24px' })
      : null;
    const revealCards = () => document.querySelectorAll(selector).forEach(card => {
      if (card.dataset.reveal || card.classList.contains('reveal') || card.dataset.todmPolishObserved) return;
      card.dataset.todmPolishObserved = 'true';
      if (!observer || card.getBoundingClientRect().top < innerHeight * .9) {
        card.classList.add('todm-polish-visible');
      } else {
        card.classList.add('todm-polish-reveal');
        observer.observe(card);
      }
    });
    revealCards();

    if (/^Archive/.test(page)) {
      const archiveMain = document.querySelector('main');
      if (archiveMain) {
        const updates = new MutationObserver(() => revealCards());
        updates.observe(archiveMain, { childList: true, subtree: true });
      }
    }

    const record = document.querySelector('[data-filk-root], [data-archive-record], [data-magic-root], [data-archive-document]');
    if (!record || reduced) return;
    const key = `todm-archive-open:${page}`;
    if (sessionStorage.getItem(key)) return;
    const opening = new MutationObserver(() => {
      if (!record.querySelector('.archive-hero, .record-hero')) return;
      opening.disconnect();
      sessionStorage.setItem(key, '1');
      record.classList.add('todm-archive-opened');
      setTimeout(() => record.classList.remove('todm-archive-opened'), 750);
    });
    opening.observe(record, { childList: true, subtree: true });
  }

  function setupOnlineGameCard() {
    if (page !== 'Archive_Level_I.html') return;
    const root = document.querySelector('[data-level-root]');
    if (!root) return;
    const addCard = () => {
      const privilege = root.querySelector('.archive-privilege');
      if (!privilege || privilege.querySelector('.archive-game-card')) return;
      privilege.id = 'games-early-access';
      const card = document.createElement('article');
      card.className = 'archive-game-card';
      card.innerHTML = '<img src="images/game-online/faction-altars.png" alt="Экран выбора четырёх фракций в «Пробуждении Леса Online»" loading="lazy"><div><span class="archive-game-status">Доступно · закрытая альфа</span><h3>Пробуждение Леса <em>Online</em></h3><p>Браузерная версия: создайте комнату или войдите по коду, выберите фракцию и подготовьтесь к партии с другими игроками.</p><div class="archive-game-actions"><a href="https://probuzhdenie-lesa.online/" target="_blank" rel="noopener noreferrer">Играть ↗</a><a href="TODM_Game_Online.html">Подробнее →</a></div></div>';
      privilege.insertBefore(card, privilege.querySelector('.archive-back'));
      if (location.hash === '#games-early-access') privilege.scrollIntoView();
    };
    addCard();
    new MutationObserver(addCard).observe(root, { childList: true, subtree: true });
  }

  function apply() {
    document.querySelectorAll('header.site-header, header.shop-header, header.game-header').forEach(setupHeader);
    const main = document.querySelector('main');
    if (!main) return;
    let siteFooter = document.querySelector('footer.site-footer, footer.shop-footer, footer.game-footer');
    if (!siteFooter && document.querySelector('header.todm-global-header')) {
      siteFooter = document.createElement('footer');
      siteFooter.className = 'site-footer';
      main.insertAdjacentElement('afterend', siteFooter);
    }
    if (siteFooter) setupFooter(siteFooter);
    if (!document.body.dataset.todmPolishReady) {
      document.body.dataset.todmPolishReady = 'true';
      setupPolish();
      setupOnlineGameCard();
    }
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', apply, { once: true });
  else apply();

  if (/^(Tom_II|Tome_II)/.test(page) || document.body?.dataset.volume || document.documentElement.classList.contains('tome-protected')) {
    new MutationObserver(apply).observe(document.documentElement, { childList: true, subtree: true });
  }
})();

// Public dossier views are recorded only for signed-in readers, without OA.
(() => {
  const page = location.pathname.split('/').pop();
  if (page === 'Archive.html') {
    const style = document.createElement('link');
    style.rel = 'stylesheet';
    style.href = 'archive-random.css';
    document.head.append(style);
    const registry = document.createElement('script');
    registry.src = 'archive-dossier-registry.js';
    registry.onload = () => {
      const random = document.createElement('script');
      random.src = 'archive-random.js';
      document.head.append(random);
    };
    document.head.append(registry);
  }
  const dossierPages = /^(Dan|Darius_Tom_I|Harvos|Milena|Filk|Morgeus|Morell|Galdvin|Sann|Forell|Hoffit|Gas|Rogan|Ranor|Soren|Sorgen|Erl|Karn|Konos|Norta|Arkon|Anrirn|Adamantriy|Lienna|Dorgus|Garaniy|Frauster_Kingdom|Maizervin_Kingdom|Cult_Doronto)\.html$/;
  if (page === 'Dokains_Archive.html') {
    const script = document.createElement('script');
    script.src = 'archive-dossier-activity.js';
    document.head.append(script);
    return;
  }
  if (!dossierPages.test(page)) return;
  const registry = document.createElement('script');
  registry.src = 'archive-dossier-registry.js';
  registry.onload = () => {
    const activity = document.createElement('script');
    activity.src = 'archive-dossier-activity.js';
    document.head.append(activity);
  };
  document.head.append(registry);
})();
