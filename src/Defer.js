/** @typedef {() => void} Eff */

/**
 * Defer work until the main thread is idle (or shortly after paint via fallback).
 * @param {Eff} eff
 * @returns {Eff}
 */
export const runWhenIdle = (eff) => () => {
  const go = () => {
    try {
      eff();
    } catch (e) {
      console.warn("[runWhenIdle]", e);
    }
  };
  if (typeof requestIdleCallback === "function") {
    requestIdleCallback(go, { timeout: 2800 });
  } else {
    requestAnimationFrame(() => {
      setTimeout(go, 0);
    });
  }
};
