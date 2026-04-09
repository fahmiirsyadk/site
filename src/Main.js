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
