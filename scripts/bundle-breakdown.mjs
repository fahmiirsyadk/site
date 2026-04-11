#!/usr/bin/env node
/**
 * Prints estimated size contribution per original module from the purs-backend-es
 * browser bundle (uses the emitted source map). Run after a compile:
 *
 *   pnpm exec spago build && node scripts/bundle-breakdown.mjs
 */
import { execFileSync } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { fileURLToPath } from "node:url";

const root = join(fileURLToPath(new URL("..", import.meta.url)));
const dir = mkdtempSync(join(tmpdir(), "site-bundle-"));
const outJs = join(dir, "app.js");
const outMap = join(dir, "app.js.map");

try {
  execFileSync(
    "pnpm",
    [
      "exec",
      "purs-backend-es",
      "bundle-app",
      "-m",
      "Main",
      "-p",
      "browser",
      "-t",
      outJs,
      "--no-build",
      "--source-maps",
    ],
    { cwd: root, stdio: "inherit" },
  );
} catch {
  process.exitCode = 1;
  rmSync(dir, { recursive: true, force: true });
  process.exit(1);
}

const map = JSON.parse(readFileSync(outMap, "utf8"));
const sources = map.sources || [];
const contents = map.sourcesContent || [];
const rows = sources
  .map((path, i) => {
    const m = path.match(/\/output-es\/(.+)$/);
    const short = m ? m[1] : path;
    return { short, bytes: Buffer.byteLength(contents[i] || "", "utf8") };
  })
  .filter((r) => r.bytes > 0)
  .sort((a, b) => b.bytes - a.bytes);

const total = rows.reduce((s, r) => s + r.bytes, 0);
const minJs = readFileSync(outJs, "utf8");
console.log(`Pre-minify ES modules (source map): ${(total / 1024).toFixed(1)} KiB listed`);
console.log(`Emitted bundle (not minified here): ${(Buffer.byteLength(minJs, "utf8") / 1024).toFixed(1)} KiB`);
console.log("");
console.log("Top 30 modules by listed source bytes:");
for (const r of rows.slice(0, 30)) {
  console.log(`${String(Math.round(r.bytes / 102.4) / 10).padStart(6)} KiB  ${r.short}`);
}

const sum = (re) => rows.filter((r) => re.test(r.short)).reduce((s, r) => s + r.bytes, 0);
console.log("");
console.log("Rough groups (sum of matching paths):");
const kb = (n) => `${(n / 1024).toFixed(1)} KiB`;
const dataRows = rows
  .filter((r) => /^Data\./.test(r.short))
  .sort((a, b) => b.bytes - a.bytes);
console.log(`  Data.*          ${kb(sum(/^Data\./))}  (${dataRows.length} modules)`);
console.log(`  Effect.*        ${kb(sum(/^Effect\./))}`);
console.log(`  Halogen.VDom.*  ${kb(sum(/^Halogen\.VDom/))}`);
console.log(`  Luna.*          ${kb(sum(/^Luna\./))}`);
console.log(`  Routing.*       ${kb(sum(/^Routing\./))}`);
console.log(`  Web.*           ${kb(sum(/^Web\./))}`);
console.log(
  `  App site tree   ${kb(
    sum(
      /^(App|Main|Pages|Components|BodyBlockHtml|Routes|Types|AnchorNav|RouteInput|TocActive|RelativeTime|LinkInterceptor)\//,
    ),
  )}`,
);
console.log(`  Main/foreign.js ${kb(sum(/^Main\/foreign\.js$/))}  (mountSeaFooter; GLSL is /assets/shaders/sea-footer.min.frag)`);
console.log("");
console.log(
  "Production `pnpm run bundle:prod` minifies this tree to ~150 KiB; most shrink is minify + tree-shake.",
);

console.log("");
console.log("Top 25 Data.* modules (largest pre-minify listed bytes):");
for (const r of dataRows.slice(0, 25)) {
  console.log(`${String(Math.round(r.bytes / 102.4) / 10).padStart(6)} KiB  ${r.short}`);
}

rmSync(dir, { recursive: true, force: true });
