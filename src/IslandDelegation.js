let markdownBound = false;

export const initMarkdownProseDelegation = (appNode) => () => {
  if (!appNode || markdownBound) return;
  markdownBound = true;
  appNode.addEventListener("click", (e) => {
    const toolBtn = e.target.closest("[data-tool-display-toggle]");
    if (toolBtn) {
      const card = toolBtn.closest('[data-component="tool-display-card"]');
      if (card && !card.classList.contains("terminal-card")) {
        const was = toolBtn.getAttribute("aria-expanded") === "true";
        toolBtn.setAttribute("aria-expanded", String(!was));
        card.classList.toggle("is-expanded", !was);
        e.preventDefault();
        return;
      }
    }
    const tToggle = e.target.closest("[data-terminal-toggle]");
    if (tToggle) {
      const id = tToggle.dataset.target;
      const body = document.getElementById(id);
      const was = tToggle.getAttribute("aria-expanded") === "true";
      tToggle.setAttribute("aria-expanded", String(!was));
      if (body) body.hidden = was;
      e.preventDefault();
      return;
    }
    const tCopy = e.target.closest("[data-terminal-copy]");
    if (tCopy) {
      navigator.clipboard
        ?.writeText(tCopy.dataset.command || "")
        .catch(() => {});
      tCopy.setAttribute("title", "Copied");
      setTimeout(() => tCopy.setAttribute("title", "Copy"), 900);
      e.preventDefault();
    }
  });
};
