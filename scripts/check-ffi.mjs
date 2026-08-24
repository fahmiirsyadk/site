import { readdir, readFile } from "node:fs/promises"
import { join } from "node:path"

const pursFiles = []

async function collect(directory) {
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    const path = join(directory, entry.name)
    if (entry.isDirectory()) await collect(path)
    else if (entry.name.endsWith(".purs")) pursFiles.push(path)
  }
}

await collect("src")

const violations = []
for (const path of pursFiles) {
  const lines = (await readFile(path, "utf8")).split("\n")
  const foreignNames = []
  for (const [index, line] of lines.entries()) {
    if (!line.trimStart().startsWith("foreign import")) continue
    if (line.trimStart().startsWith("foreign import data")) continue

    let declaration = line
    let next = index + 1
    while (!declaration.includes("::") && next < lines.length && lines[next].trim() !== "") {
      declaration += ` ${lines[next]}`
      next += 1
    }

    if (declaration.includes("::") && next < lines.length) {
      while (next < lines.length && lines[next].startsWith(" ") && lines[next].trim() !== "") {
        declaration += ` ${lines[next]}`
        next += 1
      }
    }

    if (declaration.includes("->")) {
      violations.push(`${path}:${index + 1}: use FnN instead of a curried FFI type`)
    }

    const name = declaration.match(/foreign import\s+([A-Za-z0-9_']+)\s*::/)?.[1]
    if (name !== undefined) foreignNames.push(name)
  }

  if (foreignNames.length > 0) {
    const implementationPath = path.replace(/\.purs$/, ".ts")
    const implementation = await readFile(implementationPath, "utf8").catch(() => undefined)
    if (implementation === undefined) {
      violations.push(`${path}: missing sibling FFI implementation ${implementationPath}`)
      continue
    }
    const directExports = Array.from(
      implementation.matchAll(/export\s+(?:const|let|var|function|class)\s+([A-Za-z0-9_$]+)/g),
      match => match[1],
    )
    const listedExports = Array.from(implementation.matchAll(/export\s*\{([\s\S]*?)\}\s*(?:from\s+[^\n]+)?/g))
      .flatMap(match => (match[1] ?? "").split(","))
      .map(name => name.trim().split(/\s+as\s+/).at(-1) ?? "")
      .filter(name => name !== "")
    const exportedNames = new Set([...directExports, ...listedExports])
    for (const name of foreignNames) {
      if (!exportedNames.has(name)) {
        violations.push(`${implementationPath}: missing export for foreign import ${name}`)
      }
    }
  }
}

if (violations.length > 0) {
  console.error(violations.join("\n"))
  process.exitCode = 1
} else {
  console.log(`Checked ${pursFiles.length} PureScript file(s): FFI arity and implementation exports are valid.`)
}
