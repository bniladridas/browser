(() => {
  const flag = '__browserLegacyLayoutFixInstalled';
  if (window[flag]) {
    return;
  }
  window[flag] = true;

  const isGoogleHost = /(^|\.)google\./i.test(window.location.hostname);

  const ensureViewport = () => {
    if (isGoogleHost) return;
    let viewport = document.querySelector('meta[name="viewport"]');
    if (!viewport) {
      viewport = document.createElement('meta');
      viewport.setAttribute('name', 'viewport');
      (document.head || document.documentElement).appendChild(viewport);
    }
    const current = viewport.getAttribute('content') || '';
    if (!/width\s*=\s*device-width/i.test(current)) {
      viewport.setAttribute(
        'content',
        'width=device-width, initial-scale=1, viewport-fit=cover',
      );
    }
  };

  const applyFix = () => {
    const root = document.documentElement;
    const body = document.body;
    if (!root || !body) return;
    if (isGoogleHost) {
      // Keep Google's own responsive behavior untouched.
      root.style.removeProperty('width');
      body.style.removeProperty('width');
      root.style.removeProperty('min-width');
      body.style.removeProperty('min-width');
      root.style.removeProperty('max-width');
      body.style.removeProperty('max-width');
      root.style.removeProperty('overflow-x');
      body.style.removeProperty('overflow-x');
    } else {
      root.style.setProperty('width', '100%', 'important');
      body.style.setProperty('width', '100%', 'important');
      root.style.setProperty('min-width', '0', 'important');
      body.style.setProperty('min-width', '0', 'important');
      root.style.setProperty('max-width', '100vw', 'important');
      root.style.setProperty('overflow-x', 'auto', 'important');
      body.style.setProperty('max-width', '100vw', 'important');
      body.style.setProperty('overflow-x', 'auto', 'important');
    }

    root.style.removeProperty('zoom');

    if (isGoogleHost) {
      const candidates = document.querySelectorAll(
        'iframe, [role="dialog"], [role="menu"], [aria-modal="true"]',
      );
      for (const el of candidates) {
        const rect = el.getBoundingClientRect();
        if (rect.width < 120 || rect.height < 120) continue;
        const style = window.getComputedStyle(el);
        if (style.display === 'none' || style.visibility === 'hidden') continue;
        const positioned =
          style.position === 'fixed' || style.position === 'absolute';
        if (!positioned) continue;

        if (rect.left < 8) {
          if (el.dataset.browserClampBaseTransform == null) {
            el.dataset.browserClampBaseTransform =
              style.transform === 'none' ? '' : style.transform;
          }
          const base = el.dataset.browserClampBaseTransform;
          const shift = 8 - rect.left;
          const nextTransform =
            (base ? base + ' ' : '') +
            'translateX(' +
            shift.toFixed(1) +
            'px)';
          el.style.setProperty('transform', nextTransform, 'important');
          el.style.setProperty('transform-origin', 'top left', 'important');
        } else if (el.dataset.browserClampBaseTransform != null) {
          const base = el.dataset.browserClampBaseTransform;
          if (!base) {
            el.style.setProperty('transform', 'none', 'important');
          } else {
            el.style.setProperty('transform', base, 'important');
          }
          delete el.dataset.browserClampBaseTransform;
        }
      }
    }
  };

  let fixScheduled = false;
  const scheduleFix = () => {
    if (fixScheduled) return;
    fixScheduled = true;
    window.requestAnimationFrame(() => {
      fixScheduled = false;
      applyFix();
    });
  };

  ensureViewport();
  applyFix();
  window.addEventListener('resize', scheduleFix, { passive: true });
  const observer = new MutationObserver(() => scheduleFix());
  observer.observe(document.documentElement, {
    childList: true,
    subtree: true,
  });
  setTimeout(scheduleFix, 300);
  setTimeout(scheduleFix, 1200);
})();
