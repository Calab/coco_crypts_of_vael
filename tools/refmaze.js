// Print levels from the reference web game, using its own code, for comparison with the CoCo port.
//   gjs -m tools/refmaze.js SEED [LEVEL...]      (SEED as typed on the title: number or text)
// Pulls the setup helpers, the data (ITEMS, MON, LEVELS, FILLER, LOOT) and carve/bfs/buildLevel/
// makeLevel out of reference/crypts-of-vael.html at run time and calls makeLevel for each level.
// Output per level: LEVEL n SIZE S FAR x,y DIST d, the grid (# wall, . open), then
// ITEMS n and one "x,y kind" line per item in the order buildLevel placed them,
// and MONS n with one "x,y kind carry dormant" line per monster.
import GLib from 'gi://GLib';
import System from 'system';

const path = GLib.build_filenamev([GLib.path_get_dirname(System.programPath), '..', 'reference', 'crypts-of-vael.html']);
const src = new TextDecoder().decode(GLib.file_get_contents(path)[1]);

function grabBlock(start, open, close) {         // from `start` to the bracket matching the first `open`
  let i = src.indexOf(open, start), depth = 0;
  for (; i < src.length; i++) {
    if (src[i] === open) depth++;
    else if (src[i] === close && --depth === 0) return src.slice(start, i + 1);
  }
  throw new Error('unbalanced at ' + start);
}
function grabFunction(name) {
  const start = src.indexOf('function ' + name + '(');
  if (start < 0) throw new Error('no function ' + name);
  return grabBlock(start, '{', '}');
}
function grabConst(name, open, close) {
  const start = src.indexOf('const ' + name + ' = ');
  if (start < 0) throw new Error('no const ' + name);
  return grabBlock(start, open, close) + ';';
}
function grabLine(re) {
  const m = src.match(re);
  if (!m) throw new Error('no match for ' + re);
  return m[0];
}
const code = [
  grabLine(/const DX = [^\n]*/),            // also defines DY, DIRN on the same line
  'let RNG = Math.random;',
  grabLine(/const rnd = [^\n]*/),
  grabLine(/const pick = [^\n]*/),
  grabConst('ITEMS', '{', '}'), grabConst('MON', '{', '}'), grabConst('LEVELS', '[', ']'),
  grabLine(/const FILLER = [^\n]*/), grabLine(/const LOOT = [^\n]*/), grabLine(/const LOOT_CHANCE = [^\n]*/),
  grabLine(/const hpScale = [^\n]*/),
  grabFunction('makeItem'), grabFunction('mulberry32'), grabFunction('parseSeed'), grabFunction('carve'),
  grabFunction('bfs'), grabFunction('makeLevel'), grabFunction('buildLevel'),
  'let G = {};',
  'return { parseSeed, makeLevel, setSeed: s => { G = { seed: s }; } };',
].join('\n');
const R = new Function(code)();

const seed = R.parseSeed(ARGV[0] || '');
const levels = ARGV.length > 1 ? ARGV.slice(1).map(Number) : [1, 2, 3, 4, 5];
R.setSeed(seed);
print('SEED ' + seed);
for (const n of levels) {
  const L = R.makeLevel(n), S = L.S;
  const far = L.stairs || L.mons.find(m => m.k === 'king') || { x: 0, y: 0 };
  // the far cell is where buildLevel put the ladder (levels 1-4) or the king (level 5)
  let fx = far.x, fy = far.y;
  print('LEVEL ' + n + ' SIZE ' + S + ' FAR ' + fx + ',' + fy);
  for (let y = 0; y < S; y++) {
    let row = '';
    for (let x = 0; x < S; x++) row += L.g[y * S + x] ? '#' : '.';
    print(row);
  }
  print('ITEMS ' + L.items.length);
  for (const o of L.items) print(o.x + ',' + o.y + ' ' + o.it.kind);
  print('MONS ' + L.mons.length);
  for (const m of L.mons) print(m.x + ',' + m.y + ' ' + m.k + ' ' + (m.carry ? m.carry.kind : '-') + ' ' + (m.dormant ? 1 : 0));
}
