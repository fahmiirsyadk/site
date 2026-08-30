// Shader sources re-exported through one plain TypeScript module. The backend
// copies FFI siblings into output/ and rewrites relative `.ts` imports back to
// src/, but not `?raw` asset imports — funneling every shader through here
// keeps the generated foreign.ts resolvable.
import ditheredVertex from './dithered-image.vert?raw'
import ditheredFragment from './dithered-image.frag?raw'
import hollowVertex from './hollow-mark.vert?raw'
import hollowFragment from './hollow-mark.frag?raw'
import seaVertex from './sea-footer.vert?raw'
import seaFragment from './sea-footer.frag?raw'

export const ditheredImageShaders = { vertex: ditheredVertex, fragment: ditheredFragment } as const

export const hollowMarkShaders = { vertex: hollowVertex, fragment: hollowFragment } as const

export const seaFooterShaders = { vertex: seaVertex, fragment: seaFragment } as const
