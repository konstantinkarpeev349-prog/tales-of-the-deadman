(() => {
  "use strict";

  const header = document.querySelector("[data-header]");
  const menuButton = document.querySelector("[data-menu-toggle]");
  const navigation = document.querySelector("[data-nav]");

  const closeMenu = () => {
    if (!menuButton || !navigation) return;
    menuButton.setAttribute("aria-expanded", "false");
    menuButton.setAttribute("aria-label", "Открыть меню");
    navigation.classList.remove("is-open");
    header?.classList.remove("menu-active");
    document.body.classList.remove("menu-open");
  };

  menuButton?.addEventListener("click", () => {
    const willOpen = menuButton.getAttribute("aria-expanded") !== "true";
    menuButton.setAttribute("aria-expanded", String(willOpen));
    menuButton.setAttribute("aria-label", willOpen ? "Закрыть меню" : "Открыть меню");
    navigation?.classList.toggle("is-open", willOpen);
    header?.classList.toggle("menu-active", willOpen);
    document.body.classList.toggle("menu-open", willOpen);
  });

  navigation?.querySelectorAll("a").forEach((link) => link.addEventListener("click", closeMenu));
  window.addEventListener("resize", () => {
    if (window.innerWidth > 820) closeMenu();
  });

  const updateHeader = () => header?.classList.toggle("is-scrolled", window.scrollY > 24);
  updateHeader();
  window.addEventListener("scroll", updateHeader, { passive: true });

  document.querySelectorAll("[data-year]").forEach((node) => {
    node.textContent = String(new Date().getFullYear());
  });

  const gallery = document.querySelector(".legacy-content .tom");
  const cards = gallery ? Array.from(gallery.querySelectorAll(".book-card")) : [];

  if (gallery && cards.length > 1) {
    const controls = document.createElement("div");
    controls.className = "phase-controls";
    controls.setAttribute("role", "tablist");
    controls.setAttribute("aria-label", "Фазы персонажа");

    const selectPhase = (selectedIndex, moveFocus = false) => {
      cards.forEach((card, index) => {
        const isActive = index === selectedIndex;
        card.classList.toggle("is-active", isActive);
        card.hidden = !isActive;
        card.setAttribute("role", "tabpanel");
        card.setAttribute("aria-labelledby", `phase-tab-${index + 1}`);
      });

      controls.querySelectorAll("button").forEach((button, index) => {
        const isActive = index === selectedIndex;
        button.setAttribute("aria-selected", String(isActive));
        button.tabIndex = isActive ? 0 : -1;
        if (isActive && moveFocus) button.focus();
      });
    };

    cards.forEach((card, index) => {
      card.id = `phase-panel-${index + 1}`;
      const button = document.createElement("button");
      const heading = card.querySelector("h3, .right-block_h3");
      button.type = "button";
      button.id = `phase-tab-${index + 1}`;
      button.setAttribute("role", "tab");
      button.setAttribute("aria-controls", card.id);
      button.textContent = heading?.textContent.trim() || `Фаза ${index + 1}`;
      button.addEventListener("click", () => selectPhase(index));
      button.addEventListener("keydown", (event) => {
        if (!["ArrowLeft", "ArrowRight", "Home", "End"].includes(event.key)) return;
        event.preventDefault();
        let target = index;
        if (event.key === "ArrowLeft") target = (index - 1 + cards.length) % cards.length;
        if (event.key === "ArrowRight") target = (index + 1) % cards.length;
        if (event.key === "Home") target = 0;
        if (event.key === "End") target = cards.length - 1;
        selectPhase(target, true);
      });
      controls.append(button);
    });

    gallery.classList.add("phase-gallery", "is-enhanced");
    gallery.prepend(controls);
    selectPhase(0);
  }

  const revealTargets = document.querySelectorAll(".reveal, .legacy-content > .step_1, .legacy-content > .step_2, .character-navigation, .return-cta");
  revealTargets.forEach((target) => target.classList.add("reveal"));

  if ("IntersectionObserver" in window && !window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
    const revealObserver = new IntersectionObserver((entries, observer) => {
      entries.forEach((entry) => {
        if (!entry.isIntersecting) return;
        entry.target.classList.add("is-visible");
        observer.unobserve(entry.target);
      });
    }, { threshold: 0.08, rootMargin: "0px 0px -6%" });
    revealTargets.forEach((target) => revealObserver.observe(target));
  } else {
    revealTargets.forEach((target) => target.classList.add("is-visible"));
  }

  const sectionLinks = Array.from(document.querySelectorAll(".section-nav a"));
  const trackedSections = sectionLinks
    .map((link) => document.querySelector(link.getAttribute("href")))
    .filter(Boolean);

  if (trackedSections.length && "IntersectionObserver" in window) {
    const sectionObserver = new IntersectionObserver((entries) => {
      entries.forEach((entry) => {
        if (!entry.isIntersecting) return;
        sectionLinks.forEach((link) => {
          link.classList.toggle("active", link.getAttribute("href") === `#${entry.target.id}`);
        });
      });
    }, { rootMargin: "-35% 0px -55%", threshold: 0 });
    trackedSections.forEach((section) => sectionObserver.observe(section));
  }
})();
