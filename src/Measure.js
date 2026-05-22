const TOOL_DISPLAY_COLLAPSED_MAX_PX = 200;

export const measureToolCards = (cb) => () => {
  document
    .querySelectorAll(
      '[data-component="tool-display-card"][data-block-id]:not(.terminal-card)',
    )
    .forEach((card) => {
      const id = card.dataset.blockId,
        body = card.querySelector(".tool-display-body");
      if (!id || !body) return;
      const prev = body.style.maxHeight;
      body.style.maxHeight = "none";
      const h = body.scrollHeight;
      body.style.maxHeight = prev;
      cb(id)(h)();
      const luna = card.getAttribute("data-measured-island") === "true";
      if (!luna) {
        const btn = card.querySelector(".tool-display-expand-btn");
        if (h <= TOOL_DISPLAY_COLLAPSED_MAX_PX + 1) {
          card.classList.add("tool-display-card--no-expand");
          card.classList.remove("is-expanded");
          btn?.setAttribute("aria-expanded", "false");
        } else {
          card.classList.remove("tool-display-card--no-expand");
          card.classList.add("is-expanded");
          btn?.setAttribute("aria-expanded", "true");
        }
      }
    });
};
