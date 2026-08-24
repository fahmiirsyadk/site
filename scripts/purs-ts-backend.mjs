import { existsSync } from "node:fs";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

const projectRoot = resolve(fileURLToPath(new URL("..", import.meta.url)));
const configuredBackend = process.env.PURS_TS_BACKEND;
const backend =
  configuredBackend === undefined
    ? resolve(projectRoot, "node_modules", "purs-backend-ts", "dist", "purs-ts.mjs")
    : resolve(projectRoot, configuredBackend);

if (!existsSync(backend)) {
  console.error(`purs-ts backend not found: ${backend}`);
  console.error("Run pnpm install or set PURS_TS_BACKEND to another backend CLI path.");
  process.exitCode = 1;
} else {
  const result = spawnSync(
    process.execPath,
    [backend, ...process.argv.slice(2)],
    {
      cwd: projectRoot,
      env: process.env,
      stdio: "inherit",
    },
  );
  process.exitCode = result.error === undefined ? (result.status ?? 1) : 1;
  if (result.error !== undefined) console.error(result.error.message);
}
