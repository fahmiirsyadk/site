const minuteMs = 60000;
const hourMs = 3600000;
const dayMs = 86400000;
const weekMs = 604800000;
const monthMs = 2592000000;
const yearMs = 31536000000;

let rtf = null;
function getRtf() {
  if (!rtf) {
    rtf = new Intl.RelativeTimeFormat(undefined, {
      numeric: "auto",
      style: "short",
    });
  }
  return rtf;
}

function formatAgo(ms) {
  if (ms < 0) return "soon";
  if (ms < minuteMs) return "just now";
  if (ms < hourMs) return getRtf().format(-Math.round(ms / minuteMs), "minute");
  if (ms < dayMs) return getRtf().format(-Math.round(ms / hourMs), "hour");
  if (ms < weekMs) return getRtf().format(-Math.round(ms / dayMs), "day");
  if (ms < monthMs) return getRtf().format(-Math.round(ms / weekMs), "week");
  if (ms < yearMs) return getRtf().format(-Math.round(ms / monthMs), "month");
  return getRtf().format(-Math.round(ms / yearMs), "year");
}

function parseIsoToMillis(s) {
  const d = new Date(s);
  return isNaN(d) ? -1 : d.getTime();
}

export const patchRelativeDates = () => {
  const now = Date.now();
  document.querySelectorAll("[data-relative-date]").forEach((el) => {
    const iso = el.getAttribute("data-relative-date");
    if (!iso) return;
    const t = parseIsoToMillis(iso);
    if (t < 0) return;
    const label = formatAgo(now - t);
    if (el.textContent !== label) el.textContent = label;
  });
};
