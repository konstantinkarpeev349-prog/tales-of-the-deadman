(() => {
  "use strict";

  const header = document.querySelector("[data-header]");
  const menuToggle = document.querySelector("[data-menu-toggle]");
  const navigation = document.querySelector("[data-nav]");

  const closeMenu = () => {
    header?.classList.remove("open");
    menuToggle?.setAttribute("aria-expanded", "false");
    menuToggle?.setAttribute("aria-label", "Открыть меню");
    document.body.classList.remove("menu-open");
  };

  menuToggle?.addEventListener("click", () => {
    const opening = !header?.classList.contains("open");
    header?.classList.toggle("open", opening);
    menuToggle.setAttribute("aria-expanded", String(opening));
    menuToggle.setAttribute("aria-label", opening ? "Закрыть меню" : "Открыть меню");
    document.body.classList.toggle("menu-open", opening);
  });

  navigation?.querySelectorAll("a").forEach((link) => link.addEventListener("click", closeMenu));
  window.addEventListener("resize", () => {
    if (window.innerWidth > 980) closeMenu();
  });

  const updateHeader = () => header?.classList.toggle("scrolled", window.scrollY > 24);
  updateHeader();
  window.addEventListener("scroll", updateHeader, { passive: true });

  document.querySelectorAll("[data-year]").forEach((node) => {
    node.textContent = String(new Date().getFullYear());
  });

  const markFollowingCopy = (headingId, className) => {
    const heading = document.getElementById(headingId);
    let node = heading?.nextElementSibling;
    while (node && !node.matches("h3, h4")) {
      if (node.matches("p")) node.classList.add(className);
      node = node.nextElementSibling;
    }
  };

  markFollowingCopy("observer-note", "observer-copy");
  markFollowingCopy("last-record", "last-record-copy");

  const revealTargets = document.querySelectorAll(".reveal, .legacy-content > .step_2, .character-navigation, .return-cta");
  revealTargets.forEach((target) => target.classList.add("reveal"));

  if ("IntersectionObserver" in window && !window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
    const revealObserver = new IntersectionObserver((entries, observer) => {
      entries.forEach((entry) => {
        if (!entry.isIntersecting) return;
        entry.target.classList.add("is-visible");
        observer.unobserve(entry.target);
      });
    }, { threshold: 0.06, rootMargin: "0px 0px -5%" });
    revealTargets.forEach((target) => revealObserver.observe(target));
  } else {
    revealTargets.forEach((target) => target.classList.add("is-visible"));
  }

  const sectionLinks = Array.from(document.querySelectorAll(".section-nav a"));
  const sections = sectionLinks
    .map((link) => document.querySelector(link.getAttribute("href")))
    .filter(Boolean);

  if (sections.length && "IntersectionObserver" in window) {
    const sectionObserver = new IntersectionObserver((entries) => {
      entries.forEach((entry) => {
        if (!entry.isIntersecting) return;
        sectionLinks.forEach((link) => {
          link.classList.toggle("active", link.getAttribute("href") === `#${entry.target.id}`);
        });
      });
    }, { rootMargin: "-34% 0px -56%", threshold: 0 });
    sections.forEach((section) => sectionObserver.observe(section));
  }
})();
