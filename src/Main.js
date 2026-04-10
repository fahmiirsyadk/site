export const everyMsInterval = (ms) => (eff) => () => {
  setInterval(() => eff(), ms);
};

// Run `eff` after the next paint (rAF), ensuring DOM patches are visible.
export const afterPaint = (eff) => () => {
  requestAnimationFrame(() => eff());
};

export const fetchText = (url) => (onOk) => (onErr) => () => {
  fetch(url)
    .then((resp) => {
      if (!resp.ok) {
        throw new Error(`HTTP ${resp.status} for ${url}`);
      }
      return resp.text();
    })
    .then((text) => onOk(text)())
    .catch((err) => onErr(String(err))());
};

export const extractRawHtmlContent = () => {
  const el = document.querySelector(".luna-raw-html");
  return el ? el.innerHTML : "";
};
