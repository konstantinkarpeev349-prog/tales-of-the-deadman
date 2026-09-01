(() => {
  'use strict';
  const header = document.querySelector('[data-header]');
  const toggle = document.querySelector('[data-menu-toggle]');
  const nav = document.querySelector('[data-nav]');
  const setHeader = () => header.classList.toggle('scrolled', scrollY > 30);
  setHeader();
  addEventListener('scroll', setHeader, { passive: true });
  toggle.addEventListener('click', () => {
    const open = header.classList.toggle('open');
    toggle.setAttribute('aria-expanded', String(open));
    document.body.classList.toggle('menu-open', open);
  });
  nav.addEventListener('click', event => {
    if (!event.target.matches('a')) return;
    header.classList.remove('open');
    toggle.setAttribute('aria-expanded', 'false');
    document.body.classList.remove('menu-open');
  });
  const reveals = document.querySelectorAll('.reveal');
  const reduced = matchMedia('(prefers-reduced-motion: reduce)').matches;
  if (reduced || !('IntersectionObserver' in window)) reveals.forEach(element => element.classList.add('visible'));
  else {
    const revealObserver = new IntersectionObserver((entries, observer) => entries.forEach(entry => {
      if (!entry.isIntersecting) return;
      entry.target.classList.add('visible');
      observer.unobserve(entry.target);
    }), { threshold: .12 });
    reveals.forEach(element => revealObserver.observe(element));
  }
  const sectionLinks = [...document.querySelectorAll('[data-tome-nav] a')];
  const sections = [...document.querySelectorAll('[data-section]')];
  if ('IntersectionObserver' in window) {
    const sectionObserver = new IntersectionObserver(entries => entries.forEach(entry => {
      if (!entry.isIntersecting) return;
      sectionLinks.forEach(link => link.classList.toggle('active', link.hash === `#${entry.target.id}`));
    }), { rootMargin: '-35% 0px -55%' });
    sections.forEach(section => sectionObserver.observe(section));
  }
  document.querySelector('[data-year]').textContent = new Date().getFullYear();
})();
