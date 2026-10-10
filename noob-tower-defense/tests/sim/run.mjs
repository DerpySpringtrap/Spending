// Headless simulation of the server code: runs src/shared + src/server inside a
// mocked Roblox environment (prelude.luau) on a virtual clock, then each scenario.
// Usage: npm install && npm test            (all scenarios)
//        node run.mjs scenarios/victory.luau (one scenario)
import { LuauState } from 'luau-web'
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const here = path.dirname(fileURLToPath(import.meta.url))
const src = path.resolve(here, '../../src')
const mapping = [
  ['shared', 'ReplicatedStorage/Shared'],
  ['server', 'ServerScriptService/Server'],
]

function walk(dir) {
  return fs.readdirSync(dir, { withFileTypes: true }).flatMap((e) =>
    e.isDirectory() ? walk(path.join(dir, e.name)) : [path.join(dir, e.name)],
  )
}

function buildModules() {
  let out = 'local __modules = {}\n'
  for (const [folder, dest] of mapping) {
    for (const file of walk(path.join(src, folder))) {
      if (!file.endsWith('.luau')) continue
      const rel = path.relative(path.join(src, folder), file).replace(/\.luau$/, '')
      const isScript = rel.endsWith('.server')
      const name = rel.replace(/\.server$/, '').split(path.sep).join('/')
      // Each module becomes a function; `export type` is only legal at top level.
      const body = fs.readFileSync(file, 'utf8').replace(/^export type/gm, 'type')
      out += `__modules["${dest}/${name}"] = defineModule("${dest}/${name}", "${isScript ? 'Script' : 'ModuleScript'}", function(script)\n${body}\nend)\n`
    }
  }
  return out
}

async function runScenario(file) {
  const read = (f) => fs.readFileSync(path.join(here, f), 'utf8')
  const program = [
    read('prelude.luau'),
    buildModules(),
    read('common.luau'),
    fs.readFileSync(file, 'utf8'),
    'print(#failures == 0 and "PASS" or ("FAILURES: " .. #failures))',
    'return #failures',
  ].join('\n')
  const state = await LuauState.createAsync({})
  const fn = state.loadstring(program, path.basename(file), false)
  if (typeof fn === 'string') throw new Error(`compile error: ${fn}`)
  const result = await fn()
  const failures = Array.isArray(result) ? result[0] : result
  if (failures !== 0) throw new Error(`${failures} check(s) failed`)
}

const files = process.argv.length > 2
  ? process.argv.slice(2).map((f) => path.resolve(f))
  : fs.readdirSync(path.join(here, 'scenarios')).filter((f) => f.endsWith('.luau')).map((f) => path.join(here, 'scenarios', f))

let failed = 0
for (const file of files) {
  console.log(`\n=== ${path.basename(file)}`)
  try {
    await runScenario(file)
  } catch (err) {
    failed++
    console.log(`ERROR: ${err.message ?? err}`)
  }
}
console.log(failed === 0 ? `\nAll ${files.length} scenarios passed.` : `\n${failed} scenario(s) failed.`)
process.exit(failed === 0 ? 0 : 1)
