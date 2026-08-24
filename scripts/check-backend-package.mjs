import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { existsSync, readFileSync } from "node:fs";
import { resolve } from "node:path";

const projectRoot = resolve(import.meta.dirname, "..");
const archiveName = "purs-backend-ts-0.1.0.tgz";
const archive = resolve(projectRoot, "vendor", archiveName);
const checksumFile = `${archive}.sha256`;
const installedManifest = resolve(projectRoot, "node_modules", "purs-backend-ts", "package.json");
const installedCli = resolve(projectRoot, "node_modules", "purs-backend-ts", "dist", "purs-ts.mjs");

assert.ok(existsSync(archive), `missing vendored backend archive: ${archive}`);
assert.ok(existsSync(checksumFile), `missing backend checksum: ${checksumFile}`);
assert.ok(existsSync(installedManifest), "purs-backend-ts is not installed; run pnpm install");
assert.ok(existsSync(installedCli), "installed purs-backend-ts CLI is missing");

const expectedChecksum = readFileSync(checksumFile, "utf8").trim().split(/\s+/u)[0];
const actualChecksum = createHash("sha256").update(readFileSync(archive)).digest("hex");
const manifest = JSON.parse(readFileSync(installedManifest, "utf8"));

assert.equal(actualChecksum, expectedChecksum, "vendored backend archive checksum mismatch");
assert.equal(manifest.name, "purs-backend-ts");
assert.equal(manifest.version, "0.1.0", "installed backend version does not match the vendored release");

console.log(`Checked ${manifest.name}@${manifest.version}: vendored checksum and installed CLI are valid.`);
