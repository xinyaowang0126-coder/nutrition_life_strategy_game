const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const path = require('node:path');

const source = fs.readFileSync(path.join(__dirname, '../export/web_shell.html'), 'utf8');
const scripts = [...source.matchAll(/<script>([\s\S]*?)<\/script>/g)].map(m => m[1]);
assert.equal(scripts.length, 2);

function environment(reduced = false, width = 1280, height = 720) {
  const ids = [...source.matchAll(/\bid="([^"]+)"/g)].map(m => m[1]);
  class Element {
    constructor() { this.style = {}; this.attrs = {}; this.children = []; this.naturalWidth = 1280; this.naturalHeight = 720; this.classes = new Set(); this.classList = { add: x => this.classes.add(x), remove: x => this.classes.delete(x) }; }
    set src(value) { this._src = value; if (this.onload) this.onload(); }
    get src() { return this._src || ''; }
    setAttribute(k, v) { this.attrs[k] = v; }
    removeAttribute(k) { delete this[k]; delete this.attrs[k]; }
    appendChild(el) { this.children.push(el); }
    remove() { this.removed = true; }
    focus() { this.focused = true; }
  }
  const nodes = Object.fromEntries(ids.map(id => [id, new Element()]));
  const state = { nodes, timers: [], listeners: {}, errors: [], reloads: 0, cleared: false };
  class Engine {
    static getMissingFeatures() { return []; }
    startGame(options) { state.options = options; return new Promise((resolve, reject) => { state.resolve = resolve; state.reject = reject; }); }
  }
  state.context = vm.createContext({ Engine, document: { hidden: false, getElementById: id => nodes[id] || null, createElement: () => new Element() }, innerWidth: width, innerHeight: height, matchMedia: () => ({ matches: reduced }), addEventListener: (key, fn) => { state.listeners[key] = fn; }, setInterval: fn => { state.timers.push(fn); return 1; }, clearInterval: () => { state.cleared = true; }, location: { reload: () => { state.reloads++; } }, console: { error: value => state.errors.push(value) } });
  for (const script of scripts) vm.runInContext(script.replace(/\$GODOT_CONFIG/g, '{}').replace(/\$GODOT_THREADS_ENABLED/g, 'false'), state.context);
  return state;
}

(async () => {
  const e = environment();
  const value = code => vm.runInContext(code, e.context);
  assert.equal(value('LIFE_SCENES.length'), 6);
  assert.equal(e.nodes.previous, undefined);
  assert.equal(e.nodes.next, undefined);
  e.timers[0]();
  assert.equal(value('lifeIndex'), 1);
  e.nodes.pause.onclick();
  const stopped = value('lifeIndex');
  e.timers[0]();
  assert.equal(value('lifeIndex'), stopped);
  assert.equal(e.nodes.pause.attrs['aria-pressed'], 'true');
  e.nodes.pause.onclick();
  e.timers[0]();
  assert.equal(value('lifeIndex'), 2);
  e.options.onProgress(50, 100);
  assert.equal(e.nodes.progress.value, 50);
  assert.equal(e.nodes.progress.max, 100);
  assert.match(e.nodes.status.textContent, /50%/);
  e.options.onProgress(0, 0);
  assert.equal('value' in e.nodes.progress, false);
  assert.equal('max' in e.nodes.progress, false);
  e.resolve();
  await Promise.resolve();
  assert.equal(e.nodes.loading.removed, true);
  assert.equal(e.nodes.canvas.focused, true);
  assert.equal(e.cleared, true);
  const r = environment(true);
  r.timers[0]();
  assert.equal(vm.runInContext('lifeIndex', r.context), 0);
  const m = environment(false, 390, 640);
  const active = Object.values(m.nodes).find(node => node.classes.has('front'));
  assert.ok(parseFloat(active.style.left) < 0);
  assert.ok(parseFloat(active.style.width) > 390);
  const failure = environment();
  failure.reject(new Error('network test fixture'));
  await Promise.resolve();
  assert.equal(failure.nodes.failure.style.display, 'block');
  assert.equal(failure.nodes.failure.children[0].textContent, '重新载入');
  console.log('WEB_LOADING_SHELL_TEST=' + JSON.stringify({ passed: true, sceneCount: 6, scope: 'DOM/Engine mock verifies rotation, pause, reduced-motion, mobile focus, real byte progress, indeterminate state, ready handoff and failure recovery. Not a browser render.' }));
})().catch(error => { console.error(error); process.exitCode = 1; });
