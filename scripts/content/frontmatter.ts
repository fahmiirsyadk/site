export type ParsedMarkdown = Readonly<{
  attributes: Readonly<Record<string, unknown>>
  body: string
}>

const parseAttributes = (source: string): Readonly<Record<string, unknown>> =>
  Object.fromEntries(
    source.split('\n').flatMap(line => {
      const separator = line.indexOf(':')
      if (separator < 0) {
        return []
      }
      const key = line.slice(0, separator).trim()
      const rawValue = line.slice(separator + 1).trim()
      if (rawValue.startsWith('[')) {
        try {
          return [[key, JSON.parse(rawValue)]]
        } catch {
          return [[key, []]]
        }
      }
      return [[key, rawValue.replace(/^"|"$/g, '')]]
    }),
  )

export const parseMarkdown = (source: string): ParsedMarkdown => {
  const match = source.match(/^---\s*\n([\s\S]*?)\n---\s*\n([\s\S]*)$/)
  return match === null
    ? { attributes: {}, body: source }
    : { attributes: parseAttributes(match[1] ?? ''), body: match[2] ?? '' }
}
