#!/usr/bin/env node
/**
 * Minifies `src/shaders/sea-footer.frag.glsl` and writes `public/assets/shaders/sea-footer.min.frag`
 * for runtime fetch in `mountSeaFooter` (keeps `app.js` smaller than inlining the GLSL).
 *
 * Usage: node scripts/glsl-to-inline.mjs
 */
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const root = join(__dirname, "..");
const input = join(root, "src/shaders/sea-footer.frag.glsl");
const outDir = join(root, "public/assets/shaders");
const output = join(outDir, "sea-footer.min.frag");

/** GLSL `smoothstep(edge0, edge1, x)` is only defined for edge0 < edge1; reversed literals are a common NaN source. */
const SMOOTHSTEP_LITERAL =
  /smoothstep\s*\(\s*(-?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?)\s*,\s*(-?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?)/g;

/** @param {string} src */
function assertNoReversedSmoothstepLiterals(src) {
  const hits = [...src.matchAll(SMOOTHSTEP_LITERAL)].filter((m) => {
    const a = Number.parseFloat(m[1]);
    const b = Number.parseFloat(m[2]);
    return Number.isFinite(a) && Number.isFinite(b) && a >= b;
  });
  if (hits.length) {
    throw new Error(
      `[glsl-to-inline] reversed or degenerate smoothstep(edge0, edge1, …) with numeric edges (need edge0 < edge1): ${hits[0][0].trim()}`,
    );
  }
}

/** @param {string} source */
function minifyGlsl(source) {
  let s = source.replace(/\r\n/g, "\n");
  s = s.replace(/\/\*[\s\S]*?\*\//g, " ");
  const versionMatch = s.match(/^\s*(#version[^\n]*)/m);
  const versionLine = versionMatch ? versionMatch[1].trim() : "";
  let body = versionMatch ? s.slice(versionMatch.index + versionMatch[0].length) : s;
  const lines = body.split("\n");
  const out = [];
  let buf = [];
  const flushBuf = () => {
    if (buf.length) {
      const joined = buf.join(" ").replace(/\/\/[^\n]*/g, " ").replace(/\s+/g, " ").trim();
      if (joined) out.push(joined);
      buf = [];
    }
  };
  for (const line of lines) {
    const t = line.replace(/\/\/[^\n]*/g, " ").trim();
    if (!t) continue;
    if (t.startsWith("#")) {
      flushBuf();
      out.push(t.replace(/\s+/g, " ").trim());
    } else {
      buf.push(t);
    }
  }
  flushBuf();
  const compactBody = out.join("\n");
  return versionLine ? `${versionLine}\n${compactBody}` : compactBody;
}

const raw = readFileSync(input, "utf8");
assertNoReversedSmoothstepLiterals(raw);
const min = minifyGlsl(raw);
mkdirSync(outDir, { recursive: true });
writeFileSync(output, min, "utf8");

const kb = (min.length / 1024).toFixed(1);
console.log(`[glsl-to-inline] ${input} → ${output} (${kb} KiB)`);
