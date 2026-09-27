(() => {
  'use strict';
  const stage = document.querySelector('[data-map-stage]');
  const layer = document.querySelector('[data-map-layer]');
  if (!stage || !layer) return;
  const zoomLabel = document.querySelector('[data-map-zoom]');
  const detailTitle = document.querySelector('[data-map-detail-title]');
  const detailDescription = document.querySelector('[data-map-detail-description]');
  const detailLink = document.querySelector('[data-map-detail-link]');
  const markers = [...document.querySelectorAll('[data-map-target]')];
  let scale = 1, x = 0, y = 0, drag = null;

  function update() {
    const limit = stage.clientWidth * (scale - 1) / 2;
    x = Math.max(-limit, Math.min(limit, x));
    y = Math.max(-limit, Math.min(limit, y));
    layer.style.transform = `translate(${x}px, ${y}px) scale(${scale})`;
    stage.classList.toggle('is-zoomed', scale > 1);
    zoomLabel.value = `${Math.round(scale * 100)}%`;
    document.querySelector('[data-map-zoom-out]').disabled = scale <= 1;
    document.querySelector('[data-map-zoom-in]').disabled = scale >= 3;
  }

  function zoom(direction) {
    scale = Math.max(1, Math.min(3, Math.round((scale + direction * .5) * 2) / 2));
    update();
  }

  document.querySelector('[data-map-zoom-in]').addEventListener('click', () => zoom(1));
  document.querySelector('[data-map-zoom-out]').addEventListener('click', () => zoom(-1));
  document.querySelector('[data-map-reset]').addEventListener('click', () => { scale = 1; x = 0; y = 0; update(); });

  stage.addEventListener('pointerdown', event => {
    if (scale <= 1 || event.target.closest('button')) return;
    drag = { pointerId: event.pointerId, px: event.clientX, py: event.clientY };
    stage.setPointerCapture(event.pointerId);
    stage.classList.add('is-dragging');
  });
  stage.addEventListener('pointermove', event => {
    if (!drag || drag.pointerId !== event.pointerId) return;
    x += event.clientX - drag.px;
    y += event.clientY - drag.py;
    drag.px = event.clientX;
    drag.py = event.clientY;
    update();
  });
  function stopDrag(event) {
    if (!drag || drag.pointerId !== event.pointerId) return;
    drag = null;
    stage.classList.remove('is-dragging');
  }
  stage.addEventListener('pointerup', stopDrag);
  stage.addEventListener('pointercancel', stopDrag);
  stage.addEventListener('keydown', event => {
    const moves = { ArrowLeft: [40, 0], ArrowRight: [-40, 0], ArrowUp: [0, 40], ArrowDown: [0, -40] };
    if (!moves[event.key] || scale <= 1) return;
    event.preventDefault();
    x += moves[event.key][0];
    y += moves[event.key][1];
    update();
  });

  markers.forEach(marker => marker.addEventListener('click', () => {
    const record = document.getElementById(marker.dataset.mapTarget);
    if (!record) return;
    markers.forEach(item => item.setAttribute('aria-pressed', String(item === marker)));
    detailTitle.textContent = record.querySelector('h3').textContent;
    detailDescription.textContent = record.querySelector('p').textContent;
    const link = record.querySelector('a');
    detailLink.textContent = link.textContent;
    detailLink.href = link.getAttribute('href');
  }));
  window.addEventListener('resize', update);
  update();
})();
