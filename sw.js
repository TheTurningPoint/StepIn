// InStep offline app shell.
//
// Caches the app shell (this origin's index.html + the Supabase JS CDN script) so the app can
// open with no connection — meetings often happen somewhere with no signal at all. Never touches
// Supabase API calls: those must hit the real network so the app can tell "saved" from "queued
// locally, will sync later" (see ciSubmit/ciSyncPending in index.html). Bump CACHE_NAME on any
// shell change so old caches get evicted on the next visit.
const CACHE_NAME = 'instep-shell-v1';
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
