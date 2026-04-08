"use strict";

var MONTHS = [
  "Jan", "Feb", "Mar", "Apr", "May", "Jun",
  "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
];

export function relativeTimeLabel(isoStr) {
  var d = new Date(isoStr);
  if (isNaN(d.getTime())) return isoStr;
  return MONTHS[d.getMonth()] + " " + d.getDate() + ", " + d.getFullYear();
}
