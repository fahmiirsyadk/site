"use strict";

export function scrollToHashIdImpl(id) {
  if (!id) return;
  const target = document.getElementById(id);
  if (target) {
    target.scrollIntoView({ behavior: "smooth", block: "start" });
  }
}
