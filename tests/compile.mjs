// Compiles every .luau file under src/ with the real Luau compiler (syntax check).
import { LuauState } from 'luau-web';
import { readFileSync, readdirSync, statSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..', 'src');
const files = [];
(function walk(dir) {
  for (const name of readdirSync(dir)) {
    const p = join(dir, name);
    if (statSync(p).isDirectory()) walk(p);
    else if (p.endsWith('.luau')) files.push(p);
  }
})(root);

const state = await LuauState.createAsync({});
let bad = 0;
for (const f of files) {
  const r = state.loadstring(readFileSync(f, 'utf8'), f.slice(root.length + 1), false);
  if (typeof r === 'string') { console.error('COMPILE ERROR', r); bad++; }
}
console.log(`${files.length} files compiled, ${bad} errors`);
process.exit(bad ? 1 : 0);
