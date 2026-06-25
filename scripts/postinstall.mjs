#!/usr/bin/env node
// Reapply Windows shims after pnpm install.
// Background: spago@1.0.4 on Windows spawns `purs.cmd` (with shell=true) and
// passes ~80 glob args to `purs compile`. Node 22's stricter spawn validation
// throws EINVAL. Workaround: place a real `purs.exe` (copied from
// purescript/purs.bin) into node_modules/.bin so spago's fallback lookup
// (`purs` no-ext) finds a Windows-executable and uses shell=false with
// normal argv (Node can spawn that).

import { existsSync, copyFileSync, mkdirSync, rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

const here = join(fileURLToPath(import.meta.url), "..", "..");
const root = process.cwd();
const pursPkg = join(root, "node_modules", ".pnpm", "purescript@0.15.15", "node_modules", "purescript");
const spagoPkg = join(root, "node_modules", ".pnpm", "spago@1.0.4", "node_modules", "spago");
const binDir = join(root, "node_modules", ".bin");

if (process.platform !== "win32") {
  console.log("[postinstall] non-Windows, skipping shim setup");
  process.exit(0);
}

if (!existsSync(pursPkg) || !existsSync(spagoPkg)) {
  console.log("[postinstall] purescript/spago not installed, skipping");
  process.exit(0);
}

mkdirSync(binDir, { recursive: true });

// 1) Ensure purescript package ships purs.exe (Node can spawn it directly)
const pursBin = join(pursPkg, "purs.bin");
const pursExe = join(pursPkg, "purs.exe");
if (existsSync(pursBin) && !existsSync(pursExe)) {
  copyFileSync(pursBin, pursExe);
  console.log("[postinstall] created purescript/purs.exe");
}

// 2) Place purs.exe into .bin so spago's `purs` (no-ext) lookup resolves
const binPursExe = join(binDir, "purs.exe");
if (existsSync(pursExe)) {
  copyFileSync(pursExe, binPursExe);
}

// 3) Remove conflicting shims so spago takes the `purs` (no-ext) path
for (const name of ["purs", "purs.cmd", "purs.ps1", "purs.bunx"]) {
  const p = join(binDir, name);
  if (existsSync(p)) rmSync(p);
}

// 4) Replace spago.cmd with a direct node invocation
const spagoBundle = join(spagoPkg, "bin", "bundle.js");
const spagoCmd = join(binDir, "spago.cmd");
if (existsSync(spagoBundle)) {
  writeFileSync(
    spagoCmd,
    `@echo off\r\nnode "${spagoBundle}" %*\r\n`,
    { encoding: "utf8" }
  );
}
for (const name of ["spago", "spago.ps1", "spago.bunx"]) {
  const p = join(binDir, name);
  if (existsSync(p)) rmSync(p);
}

console.log("[postinstall] Windows shims ready (purs.exe, spago.cmd)");
