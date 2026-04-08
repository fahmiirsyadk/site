"use strict";

export function interceptLinksImpl(appNode, onNavigate, onHashNavigate) {
  const prefersReducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)");

  const runNavigation = function (pathname) {
    window.history.pushState(null, "", pathname);
    onNavigate(pathname)();
  };

  const runHashNavigation = function (id) {
    if (!id) return;
    window.history.replaceState(null, "", `${window.location.pathname}#${id}`);
    const target = document.getElementById(id);
    if (target) {
      target.scrollIntoView({ behavior: "smooth", block: "start" });
    }
    onHashNavigate(id)();
  };

  const handler = function (e) {
    if (e.defaultPrevented) return;
    if (e.button !== 0) return;
    if (e.metaKey || e.ctrlKey || e.shiftKey || e.altKey) return;

    const target = e.target;
    if (!(target instanceof Element)) return;

    const link = target.closest("a[href]");
    if (!link) return;
    if (link.target === "_blank") return;
    if (link.hasAttribute("download")) return;

    const href = link.getAttribute("href");
    if (!href) return;
    if (href.startsWith("#")) {
      e.preventDefault();
      runHashNavigation(href.slice(1));
      return;
    }

    const url = new URL(link.href, window.location.origin);
    if (url.origin !== window.location.origin) return;

    e.preventDefault();

    if (document.startViewTransition && !prefersReducedMotion.matches) {
      document.startViewTransition(function () {
        runNavigation(url.pathname);
      });
      return;
    }

    runNavigation(url.pathname);
  };

  appNode.addEventListener("click", handler);
  return function () {
    appNode.removeEventListener("click", handler);
  };
}
