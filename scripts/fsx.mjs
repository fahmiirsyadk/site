import { mkdirSync, copyFileSync, cpSync, existsSync, statSync, readdirSync } from "node:fs";
import { resolve, dirname } from "node:path";

const args = process.argv.slice(2);
const cmd = args[0];

function ensureDir(dir) {
  mkdirSync(dir, { recursive: true });
}

switch (cmd) {
  case "mkdir": {
    for (const d of args.slice(1)) ensureDir(d);
    break;
  }
  case "cp": {
    const recursive = args.includes("-r");
    const positional = args.slice(1).filter((a) => a !== "-r");
    if (positional.length < 2) {
      console.error("cp: missing source or dest");
      process.exit(1);
    }
    const dest = positional[positional.length - 1];
    const sources = positional.slice(0, -1);
    for (const src of sources) {
      if (!existsSync(src)) continue;
      if (recursive) {
        const stat = statSync(src);
        if (stat.isDirectory()) {
          ensureDir(dest);
          for (const entry of readdirSync(src)) {
            const s = resolve(src, entry);
            const d = resolve(dest, entry);
            if (statSync(s).isDirectory()) {
              cpSync(s, d, { recursive: true });
            } else {
              copyFileSync(s, d);
            }
          }
        } else {
          copyFileSync(src, dest);
        }
      } else {
        copyFileSync(src, dest);
      }
    }
    break;
  }
  default:
    console.error(`Unknown command: ${cmd}`);
    process.exit(1);
}
