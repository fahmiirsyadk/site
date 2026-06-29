/* theme.js -- light/dark theme toggle.
   The pre-paint theme application (reading localStorage and setting the `dark`
   class before first paint) stays inline in <head> to avoid a flash of the
   wrong theme; this file only wires up the *interactive* toggle, so it is safe
   to load deferred. Buttons opt in with `data-theme-set="light|dark"`.

   Binding is done via event delegation on document, so it keeps working across
   the SPA soft-navigations in spa.js (which swap #page-view via innerHTML). */
(function () {
  "use strict";

  if (typeof window === "undefined" || typeof document === "undefined") return;

  function buttons() { return document.querySelectorAll("[data-theme-set]"); }

  // Apply a theme: toggle the root class, reflect pressed state, persist.
  window.__themeSet = function (mode) {
    var h = document.documentElement;
    if (mode === "dark") { h.classList.add("dark"); h.style.colorScheme = "dark"; }
    else { h.classList.remove("dark"); h.style.colorScheme = "light"; }
    buttons().forEach(function (b) {
      b.setAttribute("aria-pressed", b.getAttribute("data-theme-set") === mode ? "true" : "false");
    });
    try { localStorage.setItem("theme", mode); } catch (e) {}
  };

  // Reflect the actually-applied theme (set pre-paint) in the buttons on load,
  // so a dark-mode visitor doesn't see the light button stuck as "pressed".
  function sync() {
    var cur = document.documentElement.classList.contains("dark") ? "dark" : "light";
    buttons().forEach(function (b) {
      b.setAttribute("aria-pressed", b.getAttribute("data-theme-set") === cur ? "true" : "false");
    });
  }

  document.addEventListener("click", function (e) {
    var t = e.target;
    if (!(t instanceof Element)) return;
    var btn = t.closest("[data-theme-set]");
    if (btn) window.__themeSet(btn.getAttribute("data-theme-set"));
  });

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", sync);
  else sync();
})();
