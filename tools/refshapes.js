// Dump the reference's vector shapes as JSON, using its own code.
//   gjs -m tools/refshapes.js ICON      item icons (t = 0: one still frame, so the torch flame doesn't move)
//   gjs -m tools/refshapes.js SHAPE     monsters (later)
// Output: { kind: [[ [x, y], ... ], ...], ... } in the reference's units (floor y = 0, x across).
import GLib from 'gi://GLib';
import System from 'system';

const path = GLib.build_filenamev([GLib.path_get_dirname(System.programPath), '..', 'reference', 'crypts-of-vael.html']);
const src = new TextDecoder().decode(GLib.file_get_contents(path)[1]);

function grabBlock(start, open, close) {
  let i = src.indexOf(open, start), depth = 0;
  for (; i < src.length; i++) {
    if (src[i] === open) depth++;
    else if (src[i] === close && --depth === 0) return src.slice(start, i + 1);
  }
  throw new Error('unbalanced at ' + start);
}
const which = ARGV[0] || 'ICON';
const start = src.indexOf('const ' + which + ' = {');
if (start < 0) throw new Error('no const ' + which);
const code = [
  grabBlock(src.indexOf('function ell('), '{', '}'),
  src.match(/const mir = [^\n]*/)[0],
  src.match(/const box = [^\n]*/)[0],
  grabBlock(start, '{', '}') + ';',
  'return ' + which + ';',
].join('\n');
const table = new Function(code)();
const out = {};
for (const k of Object.keys(table)) out[k] = table[k](0);
print(JSON.stringify(out));
