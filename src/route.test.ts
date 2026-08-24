import { describe, expect, test } from 'vitest'

import { homePath, postPath, routePath, sectionPath, sshPath, urlToAppRoute } from 'purescript/App.Route/index.ts'

describe('PureScript route boundary', () => {
  test('keeps path construction in PureScript', () => {
    expect(homePath()).toBe('/')
    expect(sshPath()).toBe('/ssh/')
    expect(sectionPath({ section: 'thought' })).toBe('/thought/')
    expect(sectionPath({ section: 'lab' })).toBe('/lab/')
    expect(postPath({ section: 'thought', slug: 'hello' })).toBe('/thought/hello/')
  })

  test('parses every application route shape', () => {
    expect(routePath(urlToAppRoute('/'))).toBe('/')
    expect(routePath(urlToAppRoute('/ssh/'))).toBe('/ssh/')
    expect(routePath(urlToAppRoute('/thought/'))).toBe('/thought/')
    expect(routePath(urlToAppRoute('/thought/hello/'))).toBe('/thought/hello/')
    expect(routePath(urlToAppRoute('/lab/'))).toBe('/lab/')
    expect(routePath(urlToAppRoute('/articles/'))).toBe('/articles')
    expect(routePath(urlToAppRoute('/projects/'))).toBe('/projects')
    expect(routePath(urlToAppRoute('/projects/hello/'))).toBe('/projects/hello')
    expect(routePath(urlToAppRoute('/missing/'))).toBe('/missing')
  })
})
