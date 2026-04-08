"use strict";

export const parseIsoToMillis = function (s) {
  const t = Date.parse(s);
  return Number.isNaN(t) ? -1 : t;
};
