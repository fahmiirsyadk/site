import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { existsSync, readFileSync } from "node:fs";
import { resolve } from "node:path";

const projectRoot = resolve(import.meta.dirname, "..");
const installedCli = resolve(projectRoot, "node_modules", "purs-backend-ts", "dist", "purs-ts.mjs");

const packages = [
  { name: "purs-backend-ts", version: "0.1.0", archive: "purs-backend-ts-0.1.0.tgz" },
  { name: "purescript-foldkit", version: "0.1.0", archive: "purescript-foldkit-0.1.0.tgz", sidecar: "purs-ts.bindings.json" },
];

for (const packageContract of packages) {
  const archive = resolve(projectRoot, "vendor", packageContract.archive);
  const checksumFile = `${archive}.sha256`;
  const installedRoot = resolve(projectRoot, "node_modules", packageContract.name);
  const installedManifest = resolve(installedRoot, "package.json");
  assert.ok(existsSync(archive), `missing vendored archive: ${archive}`);
  assert.ok(existsSync(checksumFile), `missing vendored checksum: ${checksumFile}`);
  assert.ok(existsSync(installedManifest), `${packageContract.name} is not installed; run pnpm install`);

  const expectedChecksum = readFileSync(checksumFile, "utf8").trim().split(/\s+/u)[0];
  const actualChecksum = createHash("sha256").update(readFileSync(archive)).digest("hex");
  const manifest = JSON.parse(readFileSync(installedManifest, "utf8"));
  assert.equal(actualChecksum, expectedChecksum, `${packageContract.name} archive checksum mismatch`);
  assert.equal(manifest.name, packageContract.name);
  assert.equal(manifest.version, packageContract.version, `${packageContract.name} installed version mismatch`);
  if (packageContract.sidecar !== undefined) {
    assert.equal(manifest.pursTs, `./${packageContract.sidecar}`);
    assert.ok(existsSync(resolve(installedRoot, packageContract.sidecar)), `${packageContract.name} binding metadata is missing`);
  }
}

assert.ok(existsSync(installedCli), "installed purs-backend-ts CLI is missing");
console.log("Checked purs-backend-ts@0.1.0 and purescript-foldkit@0.1.0: vendored checksums, metadata, and CLI are valid.");
