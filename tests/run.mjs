// Test runner: bundles the pure shared modules with tiny Roblox shims and runs
// every *.spec.luau file in this folder inside a real Luau VM (luau-web).
//
//   cd tests && npm install && npm test
import { LuauState } from 'luau-web';
import { readFileSync, readdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));
const sharedDir = join(here, '..', 'src', 'shared');

// Modules that only need the shims below (no Instances).
const PURE = ['Config', 'Rarities', 'Mutations', 'Creatures', 'Wobble', 'Economy', 'Format'];

function bundle(specSource, specName) {
  let out = readFileSync(join(here, 'shims.luau'), 'utf8') + '\n';
  for (const name of PURE) {
    const src = readFileSync(join(sharedDir, name + '.luau'), 'utf8');
    out += `__modules[${JSON.stringify(name)}] = function(script)\n${src}\nend\n`;
  }
  out += `do\nlocal script = __scriptFor("__spec")\n${specSource}\nend\n`;
  out += `__finish(${JSON.stringify(specName)})\n`;
  return out;
}

let failed = 0;
const specs = readdirSync(here).filter((f) => f.endsWith('.spec.luau'));
for (const spec of specs) {
  const state = await LuauState.createAsync({});
  const fn = state.loadstring(bundle(readFileSync(join(here, spec), 'utf8'), spec), spec, false);
  if (typeof fn === 'string') {
    console.error(`COMPILE ERROR in ${spec}: ${fn}`);
    failed++;
    continue;
  }
  try {
    await fn();
  } catch (e) {
    console.error(`FAILED ${spec}: ${e.message || e}`);
    failed++;
  }
}
if (failed > 0) {
  console.error(`\n${failed} spec file(s) failed`);
  process.exit(1);
}
console.log('\nAll specs passed');
