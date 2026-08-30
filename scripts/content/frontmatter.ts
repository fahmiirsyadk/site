import { Option, Schema as S } from 'effect'

export type FrontmatterValue = string | ReadonlyArray<string>

export type ParsedMarkdown = Readonly<{
  attributes: Readonly<Record<string, FrontmatterValue>>
  body: string
}>

const parseArrayValue = (source: string): ReadonlyArray<string> => {
  try {
    return Option.match(S.decodeUnknownOption(S.Array(S.String))(JSON.parse(source)), {
      onNone: () => [],
      onSome: value => value,
    })
  } catch {
    return []
  }
}

const parseAttributes = (source: string): Readonly<Record<string, FrontmatterValue>> =>
  Object.fromEntries(
    source.split('\n').flatMap(line => {
      const separator = line.indexOf(':')
      if (separator < 0) {
        return []
      }
      const key = line.slice(0, separator).trim()
      const rawValue = line.slice(separator + 1).trim()
      const value: FrontmatterValue = rawValue.startsWith('[')
        ? parseArrayValue(rawValue)
        : rawValue.replace(/^"|"$/g, '')
      const entry: readonly [string, FrontmatterValue] = [key, value]
      return [entry]
    }),
  )

export const parseMarkdown = (source: string): ParsedMarkdown => {
  const match = source.match(/^---\s*\n([\s\S]*?)\n---\s*\n([\s\S]*)$/)
  return match === null
    ? { attributes: {}, body: source }
    : { attributes: parseAttributes(match[1] ?? ''), body: match[2] ?? '' }
}
