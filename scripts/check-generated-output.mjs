import { readdir, readFile } from "node:fs/promises";
import { join } from "node:path";

const outputRoot = "output";
const requiredFiles = [
  "runtime.ts",
  "effect-runtime.ts",
  "App.Entry/index.ts",
  "App.Core/index.ts",
  "App.Route/index.ts",
  "App.View/index.ts",
  "Content.Repository/index.ts",
  "Domain.Content/index.ts",
  "Runtime.Canvas/index.ts",
  "Runtime.Dither/index.ts",
  "Runtime.Frame/index.ts",
  "Runtime.HollowGeometry/index.ts",
  "Runtime.HollowMotion/index.ts",
  "Runtime.Scribble/index.ts",
  "Runtime.SeaMotion/index.ts",
];

const files = [];
const collect = async (directory) => {
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    const path = join(directory, entry.name);
    if (entry.isDirectory()) await collect(path);
    else files.push(path);
  }
};

await collect(outputRoot);

const violations = [];
const fileSet = new Set(files);
for (const relativePath of requiredFiles) {
  const path = join(outputRoot, relativePath);
  if (!fileSet.has(path))
    violations.push(`missing required backend output: ${path}`);
}

for (const path of files) {
  if (path.endsWith(".js"))
    violations.push(`JavaScript backend artifact is forbidden: ${path}`);
  if (!path.endsWith(".ts")) continue;
  const source = await readFile(path, "utf8");
  if (
    /from\s+['"][^'"]+\.js['"]|import\s*\(\s*['"][^'"]+\.js['"]\s*\)/u.test(
      source,
    )
  ) {
    violations.push(`generated TypeScript imports JavaScript: ${path}`);
  }
}

const foreignProviders = files.filter((path) => path.endsWith("/foreign.ts"));
if (foreignProviders.length === 0)
  violations.push("backend emitted no TypeScript FFI providers");

if (violations.length > 0) {
  console.error(violations.join("\n"));
  process.exitCode = 1;
} else {
  console.log(
    `Checked ${files.length} generated file(s): required roots and ${foreignProviders.length} FFI provider(s) use TypeScript only.`,
  );
}
