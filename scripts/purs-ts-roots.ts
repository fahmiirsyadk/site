import { readdirSync, readFileSync, writeFileSync } from "node:fs";
import { join, resolve } from "node:path";

const sourceDirectories = ["src", "scripts"];
const sourceExtensions = new Set([".ts", ".tsx", ".mts", ".cts"]);
const purescriptImport =
  /(?:from|import)\s*["'`]purescript\/([^\/"'`]+)\/index\.(?:ts|js)["'`]/gu;
const outputImport =
  /(?:from|import)\s*["'`](?:\.\.\/)+output\/([^\/"'`]+)\/index\.(?:ts|js)["'`]/gu;

const collectSourceFiles = (directory: string): string[] => {
  const files: string[] = [];
  for (const entry of readdirSync(directory, { withFileTypes: true })) {
    const path = join(directory, entry.name);
    if (entry.isDirectory()) files.push(...collectSourceFiles(path));
    else if (sourceExtensions.has(path.slice(path.lastIndexOf("."))))
      files.push(path);
  }
  return files;
};

export const discoverPureScriptRoots = (projectRoot: string): string[] => {
  const roots = new Set<string>();
  for (const sourceDirectory of sourceDirectories) {
    const directory = resolve(projectRoot, sourceDirectory);
    for (const path of collectSourceFiles(directory)) {
      const source = readFileSync(path, "utf8");
      for (const match of source.matchAll(purescriptImport)) {
        const moduleName = match[1];
        if (moduleName !== undefined) roots.add(moduleName);
      }
      for (const match of source.matchAll(outputImport)) {
        const moduleName = match[1];
        if (moduleName !== undefined) roots.add(moduleName);
      }
    }
  }
  return [...roots].sort();
};

export const writePureScriptRoots = (projectRoot: string): string[] => {
  const roots = discoverPureScriptRoots(projectRoot);
  const rootsFile = resolve(projectRoot, ".purs-ts-roots");
  const contents = [
    "# Generated from direct TypeScript host imports; do not edit.",
    ...roots,
    "",
  ].join("\n");
  writeFileSync(rootsFile, contents);
  return roots;
};
