const THEME_STORAGE_KEY = "theme";
const getStoredMode = () => {
  try {
    const s = localStorage.getItem(THEME_STORAGE_KEY);
    return s === "dark" ? "dark" : "light";
  } catch {
    return "light";
  }
};
const effectiveDark = (m) => m === "dark";

export const getStoredThemeMode = () => getStoredMode();

export const applyThemeMode = (mode) => () => {
  try {
    localStorage.setItem(THEME_STORAGE_KEY, mode);
  } catch {}
  document.documentElement.classList.toggle("dark", effectiveDark(mode));
  try {
    document.documentElement.style.colorScheme = effectiveDark(mode)
      ? "dark"
      : "light";
  } catch {}
};

export const patchSsrThemeButtons = (mode) => () => {
  const map = new Map([
    ["Use light theme", "light"],
    ["Use dark theme", "dark"],
  ]);
  document
    .querySelectorAll("[data-theme-controls] button[aria-label]")
    .forEach((btn) => {
      const m = map.get(btn.getAttribute("aria-label"));
      if (m) btn.setAttribute("aria-pressed", m === mode ? "true" : "false");
    });
};
