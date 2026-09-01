(() => {
  const header = document.querySelector('[data-header]');
  const menuButton = document.querySelector('[data-menu]');
  const nav = document.querySelector('#game-nav');
  const updateHeader = () => header?.classList.toggle('scrolled', window.scrollY > 24);
  updateHeader();
  addEventListener('scroll', updateHeader, { passive: true });
  menuButton?.addEventListener('click', () => {
    const open = nav.classList.toggle('open');
    menuButton.setAttribute('aria-expanded', String(open));
  });
  nav?.addEventListener('click', e => { if (e.target.closest('a')) { nav.classList.remove('open'); menuButton?.setAttribute('aria-expanded', 'false'); } });

  const observer = 'IntersectionObserver' in window ? new IntersectionObserver(entries => entries.forEach(entry => { if (entry.isIntersecting) { entry.target.classList.add('visible'); observer.unobserve(entry.target); } }), { threshold: .12 }) : null;
  document.querySelectorAll('.reveal').forEach(el => observer ? observer.observe(el) : el.classList.add('visible'));

  const carousel = document.querySelector('[data-carousel]');
  const track = carousel?.querySelector('[data-track]');
  const step = () => (track?.querySelector('figure')?.getBoundingClientRect().width || 300) + 18;
  carousel?.querySelector('[data-prev]')?.addEventListener('click', () => track.scrollBy({ left: -step(), behavior: 'smooth' }));
  carousel?.querySelector('[data-next]')?.addEventListener('click', () => track.scrollBy({ left: step(), behavior: 'smooth' }));
  track?.addEventListener('keydown', e => { if (e.key === 'ArrowLeft' || e.key === 'ArrowRight') { e.preventDefault(); track.scrollBy({ left: e.key === 'ArrowLeft' ? -step() : step(), behavior: 'smooth' }); } });
  let down = false, startX = 0, startScroll = 0;
  track?.addEventListener('pointerdown', e => { down = true; startX = e.clientX; startScroll = track.scrollLeft; track.setPointerCapture(e.pointerId); });
  track?.addEventListener('pointermove', e => { if (down) track.scrollLeft = startScroll - (e.clientX - startX); });
  track?.addEventListener('pointerup', () => { down = false; });
  track?.addEventListener('pointercancel', () => { down = false; });
})();
