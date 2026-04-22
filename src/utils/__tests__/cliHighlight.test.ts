import { describe, expect, test } from 'bun:test'
import { getCliHighlightPromise, getLanguageName } from '../cliHighlight.js'

describe('cliHighlight', () => {
  test('returns a stable shared promise', () => {
    const first = getCliHighlightPromise()
    const second = getCliHighlightPromise()
    expect(first).toBe(second)
  })

  test('resolves to highlight helpers', async () => {
    const highlight = await getCliHighlightPromise()
    expect(highlight).not.toBeNull()
    expect(typeof highlight?.highlight).toBe('function')
    expect(typeof highlight?.supportsLanguage).toBe('function')
  })

  test('returns TypeScript for ts files', async () => {
    await expect(getLanguageName('foo.ts')).resolves.toBe('TypeScript')
  })

  test('returns unknown for files without extension', async () => {
    await expect(getLanguageName('Dockerfile')).resolves.toBe('unknown')
  })

  test('returns unknown for unsupported extensions', async () => {
    await expect(getLanguageName('file.xyz123')).resolves.toBe('unknown')
  })
})
