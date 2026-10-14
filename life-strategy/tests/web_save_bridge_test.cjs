// Unit model of IndexedDB transactions; this is not a browser acceptance test.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const source = fs.readFileSync(require('node:path').join(__dirname, '../scripts/stories/web_save_bridge.js'), 'utf8');
const tick = () => new Promise(resolve => setImmediate(resolve));

function database(rows = new Map(), faults = {}) {
    return {
        rows, faults,
        open() {
            const request = {};
            setImmediate(() => {
                if (faults.denied) { request.error = { name: 'SecurityError' }; request.onerror(); return; }
                request.result = {
                    objectStoreNames: { contains: () => true }, close() {},
                    transaction(_, access) {
                        const tx = { error: null };
                        const pending = [];
                        tx.objectStore = () => ({
                            put(text, key) { pending.push([key, text]); },
                            openCursor() {
                                const cursor = {};
                                const entries = [...rows]; let index = 0;
                                const advance = () => setImmediate(() => {
                                    cursor.result = index < entries.length ? {
                                        key: entries[index][0], value: entries[index][1],
                                        continue() { index++; advance(); }
                                    } : null;
                                    cursor.onsuccess();
                                    if (!cursor.result) setImmediate(() => tx.oncomplete());
                                });
                                advance(); return cursor;
                            }
                        });
                        if (access === 'readwrite') setImmediate(() => {
                            if (faults.quota) { tx.error = { name: 'QuotaExceededError' }; tx.onabort(); return; }
                            pending.forEach(([key, value]) => rows.set(key, value));
                            tx.oncomplete();
                        });
                        return tx;
                    }
                };
                request.onsuccess();
            });
            return request;
        }
    };
}

function page(idb) {
    const downloads = [], inputs = [];
    const document = {
        body: { appendChild(node) { if (node.tag === 'input') inputs.push(node); } },
        createElement(tag) { return { tag, style: {}, click() { if (tag === 'a') downloads.push(this.download); }, remove() {} }; }
    };
    const context = vm.createContext({ indexedDB: idb, document, TextEncoder, Blob, URL: { createObjectURL: () => 'blob:unit-test', revokeObjectURL() {} }, setTimeout() {} });
    vm.runInContext(source, context);
    return { api: context.NutritionLifeSaves, context, downloads, inputs };
}

async function ready(api) {
    for (let i = 0; i < 100; i++) {
        if (JSON.parse(api.status()).phase === 'ready') return;
        await tick();
    }
    throw new Error('Bridge did not become ready');
}

async function result(api, id) {
    for (let i = 0; i < 100; i++) {
        const value = api.poll(id);
        if (value) return JSON.parse(value);
        await tick();
    }
    throw new Error('Operation did not finish');
}

(async () => {
    const idb = database();
    const first = page(idb);
    await ready(first.api);
    const key = 'choir_week:auto';
    const id = first.api.put(key, '{"day":4}', '');
    assert.equal(first.api.poll(id), '');
    assert.equal(first.api.read(key), '');
    assert.equal((await result(first.api, id)).ok, true);
    assert.equal(first.api.read(key), '{"day":4}');
    assert.equal(idb.rows.get(key), '{"day":4}');
    const secondId = first.api.put(key, '{"day":5}', '{"day":4}');
    assert.equal((await result(first.api, secondId)).ok, true);
    assert.equal(idb.rows.get(key + ':backup'), '{"day":4}');
    const campus = first.api.put('campus_exam:manual_1', '{"day":2}', '');
    assert.equal((await result(first.api, campus)).ok, true);
    const nextPage = page(idb); // Fresh JS realm, same persisted object store.
    await ready(nextPage.api);
    assert.equal(nextPage.api.read(key), '{"day":5}');
    assert.equal(nextPage.api.read('campus_exam:manual_1'), '{"day":2}');
    idb.faults.quota = true;
    const failed = nextPage.api.put(key, '{"day":6}', '{"day":5}');
    assert.equal((await result(nextPage.api, failed)).ok, false);
    assert.equal(nextPage.api.read(key), '{"day":5}');
    assert.equal(idb.rows.get(key + ':backup'), '{"day":4}');
    idb.faults.quota = false;
    const queuedA = nextPage.api.put(key, 'A', '{"day":5}');
    const queuedB = nextPage.api.put(key, 'B', 'A');
    await result(nextPage.api, queuedA); await result(nextPage.api, queuedB);
    assert.equal(nextPage.api.read(key), 'B');
    assert.equal(nextPage.api.read(key + ':backup'), 'A');
    assert.equal((await result(nextPage.api, nextPage.api.put('../bad', '{}', ''))).ok, false);
    const denied = page(database(new Map(), { denied: true }));
    await tick();
    assert.equal(JSON.parse(denied.api.status()).phase, 'unavailable');
    assert.equal((await result(denied.api, denied.api.put(key, '{}', ''))).ok, false);
    assert.equal(nextPage.api.download('nutrition-life-choir_week.json', '{"day":5}'), true);
    assert.deepEqual(nextPage.downloads, ['nutrition-life-choir_week.json']);
    const pick = nextPage.api.pick();
    nextPage.inputs.at(-1).files = [{ size: 9, text: async () => '{"day":5}' }];
    await nextPage.inputs.at(-1).onchange();
    assert.deepEqual(await result(nextPage.api, pick), { ok: true, text: '{"day":5}' });
    const cancel = nextPage.api.pick(); nextPage.inputs.at(-1).oncancel();
    assert.equal((await result(nextPage.api, cancel)).error, 'cancelled');
    console.log(JSON.stringify({ ok: true, scope: 'Node unit transaction model: completion ack, cold realm reload, backup, quota abort, write ordering, story isolation, file picker and download. Not real browser IndexedDB/WebGL.', checks: 12 }));
})().catch(error => { console.error(error); process.exitCode = 1; });
