import { loadedPosts } from './content-loader.ts'

export const posts = loadedPosts

export const formatDateImpl = (value: string): string => {
  const parsed = new Date(value)
  return Number.isNaN(parsed.getTime())
    ? value
    : new Intl.DateTimeFormat('en', {
        day: 'numeric',
        month: 'short',
        year: 'numeric',
      }).format(parsed)
}
