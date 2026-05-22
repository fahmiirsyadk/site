export const everyMsInterval = (ms) => (eff) => () =>
  setInterval(() => eff(), ms);

export const afterPaint = (eff) => () => requestAnimationFrame(() => eff());

export const fetchText = (url) => (onOk) => (onErr) => () => {
  fetch(url)
    .then((r) => {
      if (!r.ok) throw new Error(`HTTP ${r.status}`);
      return r.text();
    })
    .then((t) => onOk(t)())
    .catch((e) => onErr(String(e))());
};
