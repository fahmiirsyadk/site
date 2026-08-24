import { existsSync, rmSync } from "node:fs";
import { delimiter, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

const projectRoot = resolve(fileURLToPath(new URL("..", import.meta.url)));
const localBin = resolve(projectRoot, "node_modules", ".bin");
const spago = resolve(
  localBin,
  process.platform === "win32" ? "spago.cmd" : "spago",
);

export const buildPureScript = (): number => {
  rmSync(resolve(projectRoot, "output"), { recursive: true, force: true });
  const pathEntries = [
    existsSync(resolve(projectRoot, "purs")) ? projectRoot : undefined,
    localBin,
    process.env.PATH,
  ].filter((entry): entry is string => entry !== undefined);

  const result = spawnSync(spago, ["build"], {
    cwd: projectRoot,
    env: { ...process.env, PATH: pathEntries.join(delimiter) },
    stdio: "inherit",
  });

  if (result.error !== undefined) {
    console.error(result.error.message);
    return 1;
  }

  return result.status ?? 1;
};

if (
  process.argv[1] !== undefined &&
  resolve(process.argv[1]) === fileURLToPath(import.meta.url)
) {
  process.exitCode = buildPureScript();
}
