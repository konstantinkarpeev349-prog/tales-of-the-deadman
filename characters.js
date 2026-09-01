(() => {
  'use strict';
  const header = document.querySelector('[data-header]');
  const toggle = document.querySelector('[data-menu-toggle]');
  const nav = document.querySelector('[data-nav]');
  const cards = [...document.querySelectorAll('.character-card')];
  const filters = [...document.querySelectorAll('[data-filter]')];
  const search = document.querySelector('[data-search]');
  const clear = document.querySelector('[data-clear]');
  const empty = document.querySelector('[data-empty]');
  const count = document.querySelector('[data-visible-count]');
  const requestedFilter = new URLSearchParams(location.search).get('faction');
  let activeFilter = filters.some(button => button.dataset.filter === requestedFilter) ? requestedFilter : 'all';
  const setHeader = () => header.classList.toggle('scrolled', scrollY > 30);
  setHeader(); addEventListener('scroll', setHeader, { passive: true });
  toggle.addEventListener('click', () => { const open = header.classList.toggle('open'); toggle.setAttribute('aria-expanded', String(open)); document.body.classList.toggle('menu-open', open); });
  nav.addEventListener('click', event => { if (!event.target.matches('a')) return; header.classList.remove('open'); toggle.setAttribute('aria-expanded', 'false'); document.body.classList.remove('menu-open'); });

  const apply = () => {
    const query = search.value.trim().toLocaleLowerCase('ru');
    let visible = 0;
    cards.forEach((card, index) => {
      const factionMatch = activeFilter === 'all' || card.dataset.faction === activeFilter;
      const nameMatch = card.dataset.name.toLocaleLowerCase('ru').includes(query);
      const show = factionMatch && nameMatch;
      card.hidden = !show;
      card.style.setProperty('--delay', `${Math.min(index, 8) * 35}ms`);
      if (show) visible += 1;
    });
    count.textContent = visible;
    empty.hidden = visible !== 0;
    clear.hidden = !query;
  };
  filters.forEach(button => button.addEventListener('click', () => {
    activeFilter = button.dataset.filter;
    filters.forEach(item => { const active = item === button; item.classList.toggle('active', active); item.setAttribute('aria-pressed', String(active)); });
    apply();
  }));
  filters.forEach(button => {
    const active = button.dataset.filter === activeFilter;
    button.classList.toggle('active', active);
    button.setAttribute('aria-pressed', String(active));
  });
  search.addEventListener('input', apply);
  clear.addEventListener('click', () => { search.value = ''; search.focus(); apply(); });
  document.querySelector('[data-reset]').addEventListener('click', () => { activeFilter = 'all'; search.value = ''; filters.forEach((item, index) => { item.classList.toggle('active', index === 0); item.setAttribute('aria-pressed', String(index === 0)); }); apply(); });
  document.querySelector('[data-year]').textContent = new Date().getFullYear();
  apply();
})();
