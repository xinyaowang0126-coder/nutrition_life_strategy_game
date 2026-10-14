/* Only data strings cross the Godot bridge. IndexedDB completion is the ack. */
(function (host) {
    "use strict";
    if (host.NutritionLifeSaves) return;
    const MAX_BYTES = 4194304;
    const cache = new Map();
    const operations = new Map();
    const validated = new Set();
    let db = null, phase = "opening", error = "", nextId = 1;
    let writes = Promise.resolve();
    const validKey = key => /^[a-z0-9_]{1,64}:(auto|manual_[123])(:backup)?$/.test(key);
    const fail = e => ({ ok: false, error: (e && e.name) || "StorageError" });
    const newOperation = () => { const id = nextId++; operations.set(id, null); return id; };
    const finish = (id, value) => operations.set(id, value);

    function open() {
        if (db || phase === "loading") return;
        phase = "loading"; error = "";
        try {
            if (!host.indexedDB) throw new Error("IndexedDBUnavailable");
            const request = host.indexedDB.open("nutrition-life-strategy-saves", 1);
            request.onupgradeneeded = () => {
                if (!request.result.objectStoreNames.contains("slots")) request.result.createObjectStore("slots");
            };
            request.onblocked = () => { phase = "unavailable"; error = "StorageBlocked"; };
            request.onerror = () => { phase = "unavailable"; error = request.error?.name || "StorageOpenFailed"; };
            request.onsuccess = () => {
                db = request.result;
                db.onversionchange = () => { db.close(); db = null; phase = "unavailable"; error = "StorageVersionChanged"; };
                const pending = new Map();
                const tx = db.transaction("slots", "readonly");
                const cursor = tx.objectStore("slots").openCursor();
                cursor.onsuccess = () => {
                    const row = cursor.result;
                    if (!row) return;
                    if (typeof row.key === "string" && validKey(row.key) && typeof row.value === "string") pending.set(row.key, row.value);
                    row.continue();
                };
                tx.oncomplete = () => { cache.clear(); validated.clear(); pending.forEach((value, key) => cache.set(key, value)); phase = "ready"; };
                tx.onabort = tx.onerror = () => { db.close(); db = null; phase = "unavailable"; error = "StorageReadFailed"; };
            };
        } catch (e) { phase = "unavailable"; error = e.message || e.name; }
    }

    function put(key, text, backup) {
        const id = newOperation();
        if (!validKey(key) || key.endsWith(":backup") || typeof text !== "string" || new TextEncoder().encode(text).length > MAX_BYTES || typeof backup !== "string") {
            finish(id, { ok: false, error: "InvalidSaveInput" }); return id;
        }
        writes = writes.catch(() => {}).then(() => new Promise(resolve => {
            if (phase !== "ready" || !db) { finish(id, { ok: false, error: "StorageUnavailable" }); resolve(); return; }
            let tx;
            try {
                try { tx = db.transaction("slots", "readwrite", { durability: "strict" }); }
                catch (_) { tx = db.transaction("slots", "readwrite"); }
                const store = tx.objectStore("slots");
                const keptBackup = validated.has(key) ? cache.get(key) : backup;
                if (keptBackup) store.put(keptBackup, key + ":backup");
                store.put(text, key);
                tx.oncomplete = () => {
                    cache.set(key, text);
                    validated.add(key);
                    if (keptBackup) cache.set(key + ":backup", keptBackup);
                    finish(id, { ok: true }); resolve();
                };
                tx.onabort = tx.onerror = () => { finish(id, fail(tx.error)); resolve(); };
            } catch (e) { finish(id, fail(e)); resolve(); }
        }));
        return id;
    }

    function download(filename, text) {
        if (typeof text !== "string" || new TextEncoder().encode(text).length > MAX_BYTES) return false;
        const url = host.URL.createObjectURL(new Blob([text], { type: "application/json;charset=utf-8" }));
        const anchor = host.document.createElement("a");
        anchor.href = url;
        anchor.download = filename.replace(/[^a-zA-Z0-9_.-]/g, "_");
        host.document.body.appendChild(anchor); anchor.click(); anchor.remove();
        host.setTimeout(() => host.URL.revokeObjectURL(url), 10000);
        return true;
    }

    function pick() {
        const id = newOperation();
        const input = host.document.createElement("input");
        input.type = "file"; input.accept = ".json,application/json"; input.style.display = "none";
        host.document.body.appendChild(input);
        const done = value => { finish(id, value); input.remove(); };
        input.oncancel = () => done({ ok: false, error: "cancelled" });
        input.onchange = async () => {
            const file = input.files && input.files[0];
            if (!file) { done({ ok: false, error: "cancelled" }); return; }
            if (file.size > MAX_BYTES) { done({ ok: false, error: "too_large" }); return; }
            try { done({ ok: true, text: await file.text() }); } catch (e) { done(fail(e)); }
        };
        input.click(); return id;
    }

    host.NutritionLifeSaves = {
        status: () => JSON.stringify({ phase, error }),
        read: key => validKey(key) ? (cache.get(key) || "") : "",
        mark_valid: (key, text) => { if (validKey(key) && cache.get(key) === text) validated.add(key); },
        put, download, pick,
        poll: id => {
            const result = operations.get(id);
            if (result === null) return "";
            operations.delete(id);
            return JSON.stringify(result || { ok: false, error: "UnknownOperation" });
        },
        retry: open
    };
    open();
})(globalThis);
