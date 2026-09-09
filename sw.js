// InStep offline app shell.
//
// Caches the app shell (this origin's index.html + the Supabase JS CDN script) so the app can
// open with no connection — meetings often happen somewhere with no signal at all. Never touches
// Supabase API calls: those must hit the real network so the app can tell "saved" from "queued
// locally, will sync later" (see ciSubmit/ciSyncPending in index.html). Bump CACHE_NAME on any
// shell change so old caches get evicted on the next visit.
const CACHE_NAME = 'instep-shell-v2';
const SHELL_URLS = [
  './',
  './index.html',
  'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2',
];

self.addEventListener('install', (event) => {
  self.skipWaiting();
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then((cache) => Promise.all(SHELL_URLS.map((u) => cache.add(u).catch(() => {}))))
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys()
      .then((names) => Promise.all(names.filter((n) => n !== CACHE_NAME).map((n) => caches.delete(n))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (req.method !== 'GET') return;

  let url;
  try { url = new URL(req.url); } catch (e) { return; }
  // Never intercept Supabase (data must hit the real network, or fail cleanly so the app can queue it).
  if (url.hostname.endsWith('supabase.co')) return;

  if (req.mode === 'navigate') {
    // Page loads: try the network for the freshest build, fall back to the cached shell offline.
    event.respondWith(
      fetch(req)
        .then((resp) => {
          caches.open(CACHE_NAME).then((cache) => cache.put('./index.html', resp.clone()));
          return resp;
        })
        .catch(() => caches.match('./index.html').then((r) => r || caches.match('./')))
    );
    return;
  }

  // Everything else (the Supabase CDN script, etc.): cache-first, refresh in the background.
  event.respondWith(
    caches.match(req).then((cached) => {
      const network = fetch(req).then((resp) => {
        if (resp && resp.ok) caches.open(CACHE_NAME).then((cache) => cache.put(req, resp.clone()));
        return resp;
      }).catch(() => cached);
      return cached || network;
    })
  );
});

// ── BACKGROUND SYNC ── retries queued check-ins even if the app is fully closed when the
// connection comes back. Chrome/Android only — Safari has no Background Sync API at all, which
// is fine: index.html also syncs the same IndexedDB queue in the foreground (on 'online' and on
// every app open), so this is a bonus for the platforms that support it, not a requirement.
// Same anon key as index.html's SUPABASE_KEY — public by design, see CLAUDE.md.
const SUPABASE_URL = 'https://vhxswxilkuwsxwpsdjxl.supabase.co';
const SUPABASE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZoeHN3eGlsa3V3c3h3cHNkanhsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE1NzM3MzgsImV4cCI6MjA5NzE0OTczOH0.2aSbvhbkgJyO3GXAbD7o9osqGZWtuco0XRAlVXALr8M';
const CI_QUEUE_DB = 'instep-ci-queue', CI_QUEUE_STORE = 'pending';

function ciQueueDB() {
  return new Promise((resolve, reject) => {
    const req = indexedDB.open(CI_QUEUE_DB, 1);
    req.onupgradeneeded = () => { req.result.createObjectStore(CI_QUEUE_STORE, { keyPath: 'id' }); };
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
  });
}
async function ciQueueGetAll() {
  const db = await ciQueueDB();
  return new Promise((resolve, reject) => {
    const tx = db.transaction(CI_QUEUE_STORE, 'readonly');
    const req = tx.objectStore(CI_QUEUE_STORE).getAll();
    req.onsuccess = () => resolve(req.result || []);
    req.onerror = () => reject(req.error);
  });
}
async function ciQueueRemove(id) {
  const db = await ciQueueDB();
  return new Promise((resolve, reject) => {
    const tx = db.transaction(CI_QUEUE_STORE, 'readwrite');
    tx.objectStore(CI_QUEUE_STORE).delete(id);
    tx.oncomplete = resolve;
    tx.onerror = () => reject(tx.error);
  });
}

self.addEventListener('sync', (event) => {
  if (event.tag === 'sync-checkins') event.waitUntil(syncQueuedCheckins());
});

async function syncQueuedCheckins() {
  const pending = await ciQueueGetAll().catch(() => []);
  for (const record of pending) {
    const { _token, ...body } = record;
    if (!_token) continue; // no session to auth with — leave it queued, the foreground sync path (which reads the live session) will pick it up
    try {
      const resp = await fetch(SUPABASE_URL + '/rest/v1/checkins', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'apikey': SUPABASE_KEY,
          'Authorization': 'Bearer ' + _token,
          'Prefer': 'return=minimal',
        },
        body: JSON.stringify(body),
      });
      // 2xx = saved; 409 = duplicate key, meaning it already synced some other way — either way, done.
      if (resp.ok || resp.status === 409) await ciQueueRemove(record.id);
      // any other status: leave it queued, a later sync retry (or the app's own foreground sync) will handle it
    } catch (e) {
      return; // still offline/unreachable — stop this pass; the browser will fire 'sync' again later
    }
  }
}
