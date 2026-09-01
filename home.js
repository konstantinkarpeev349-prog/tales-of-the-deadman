(() => {
  'use strict';
  const header = document.querySelector('[data-header]');
  const toggle = document.querySelector('[data-menu-toggle]');
  const nav = document.querySelector('[data-nav]');
  const setHeader = () => header.classList.toggle('scrolled', scrollY > 30);
  setHeader(); addEventListener('scroll', setHeader, { passive: true });
  toggle.addEventListener('click', () => { const open = header.classList.toggle('open'); toggle.setAttribute('aria-expanded', open); document.body.classList.toggle('menu-open', open); });
  nav.addEventListener('click', e => { if (e.target.matches('a')) { header.classList.remove('open'); toggle.setAttribute('aria-expanded', 'false'); document.body.classList.remove('menu-open'); } });
  const carousel = document.querySelector('[data-carousel]');
  const viewport = carousel.querySelector('[data-viewport]');
  const track = carousel.querySelector('[data-track]');
  const cards = [...carousel.querySelectorAll('.volume-card')];
  const prev = carousel.querySelector('[data-prev]');
  const next = carousel.querySelector('[data-next]');
  const data = [
    ['I', 'Легенда о короле докаинов', 'Tom_I.html'], ['II', 'Кризис Турунг-Гарха'], ['III', 'Убийца богов'],
    ['IV', 'Лазерное сердце'], ['V', 'Бесплатная любовь'], ['VI', 'Книга желаний']
  ];
  let active = 0, startX = 0, delta = 0, pointer = null, dragged = false, wheelLock = false;
  const render = () => {
    cards.forEach((card, i) => { const offset = i - active; card.style.setProperty('--offset', offset); card.dataset.distance = Math.abs(offset); card.setAttribute('aria-hidden', Math.abs(offset) > 1); card.querySelector('button').tabIndex = Math.abs(offset) <= 1 ? 0 : -1; });
    document.querySelector('[data-volume-number]').textContent = `Том ${data[active][0]}`;
    document.querySelector('[data-volume-title]').textContent = data[active][1];
    document.querySelector('[data-position]').textContent = `${String(active + 1).padStart(2, '0')} / 06`;
    document.querySelector('[data-status]').textContent = data[active][2] ? 'Доступен для чтения' : 'Скоро';
    const link = document.querySelector('[data-open-volume]'); link.hidden = !data[active][2]; if (data[active][2]) link.href = data[active][2];
    prev.disabled = active === 0; next.disabled = active === data.length - 1;
  };
  const select = i => { active = Math.max(0, Math.min(data.length - 1, i)); render(); };
  prev.addEventListener('click', () => select(active - 1)); next.addEventListener('click', () => select(active + 1));
  cards.forEach((card, i) => card.querySelector('button').addEventListener('click', () => { if (dragged) return; if (i !== active) select(i); else if (data[i][2]) location.href = data[i][2]; }));
  carousel.addEventListener('keydown', e => { if (e.key === 'ArrowLeft') { e.preventDefault(); select(active - 1); } if (e.key === 'ArrowRight') { e.preventDefault(); select(active + 1); } if (e.key === 'Home') select(0); if (e.key === 'End') select(5); });
  carousel.addEventListener('wheel', e => { if (wheelLock || Math.abs(e.deltaY) < 8) return; const target = active + Math.sign(e.deltaY); if (target < 0 || target > 5) return; e.preventDefault(); select(target); wheelLock = true; setTimeout(() => wheelLock = false, 450); }, { passive: false });
  viewport.addEventListener('pointerdown', e => { if (e.pointerType === 'mouse' && e.button) return; pointer = e.pointerId; startX = e.clientX; delta = 0; dragged = false; track.classList.add('dragging'); viewport.setPointerCapture(pointer); });
  viewport.addEventListener('pointermove', e => { if (e.pointerId !== pointer) return; delta = e.clientX - startX; if (Math.abs(delta) > 8) dragged = true; });
  const finish = e => { if (e.pointerId !== pointer) return; if (Math.abs(delta) > 44) select(active + (delta < 0 ? 1 : -1)); track.classList.remove('dragging'); pointer = null; setTimeout(() => dragged = false); };
  viewport.addEventListener('pointerup', finish); viewport.addEventListener('pointercancel', finish);
  document.querySelector('[data-year]').textContent = new Date().getFullYear(); render();
})();
