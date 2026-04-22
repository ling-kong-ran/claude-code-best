// highlight.js's type defs carry `/// <reference lib="dom" />`. SSETransport,
// mcp/client, ssh, dumpPrompts use DOM types (TextDecodeOptions, RequestInfo)
// that only typecheck because this file's imports pull lib.dom in. tsconfig has
// lib: ["ESNext"] only — fixing the actual DOM-type deps is a separate sweep;
// this ref preserves the status quo.
/// <reference lib="dom" />

import { extname } from 'path'
import {
  highlight as cliHighlight,
  supportsLanguage,
} from 'cli-highlight'
import highlightJs from 'highlight.js'

export type CliHighlight = {
  highlight: typeof cliHighlight
  supportsLanguage: typeof supportsLanguage
}

// This used to lazy-load cli-highlight/highlight.js so startup paths that never
// render code blocks or inspect file languages did not pay the cost of loading
// the full highlight.js grammar registry. That reduced cold-start time and RSS,
// and avoided past Windows CI flakes caused by pulling highlight.js in too early.
//
// We switched back to static imports because `bun build --compile` was emitting
// an exe that later tried to resolve highlight.js from `B:\~BUN\root\ccb.exe`
// at runtime. By importing both modules statically, Bun can bundle them into the
// executable up front and the compiled binary no longer depends on runtime package
// resolution for these highlight paths.
const loadedCliHighlight: CliHighlight = {
  highlight: cliHighlight,
  supportsLanguage,
}

const loadedGetLanguage = highlightJs.getLanguage.bind(highlightJs)
const cliHighlightPromise = Promise.resolve<CliHighlight | null>(loadedCliHighlight)

export function getCliHighlightPromise(): Promise<CliHighlight | null> {
  return cliHighlightPromise
}

/**
 * eg. "foo/bar.ts" → "TypeScript". Awaits the shared cli-highlight load,
 * then reads highlight.js's language registry. All callers are telemetry
 * (OTel counter attributes, permission-dialog unary events) — none block
 * on this, they fire-and-forget or the consumer already handles Promise<string>.
 */
export async function getLanguageName(file_path: string): Promise<string> {
  await getCliHighlightPromise()
  const ext = extname(file_path).slice(1)
  if (!ext) return 'unknown'
  return loadedGetLanguage(ext)?.name ?? 'unknown'
}
