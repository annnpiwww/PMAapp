// Service Worker for Lapor Error PWA
// Scope: /lapor/

const CACHE_NAME = 'lapor-v3';
const SHELL_ASSETS = [
  '/lapor/',
  '/lapor/index.html',
  '/lapor/lapor.css',
  '/lapor/app.js',
  '/lapor/lapor-core.js',
  '/lapor/config.js',
  '/lapor/manifest.webmanifest',
  '/lapor/kelola/',
  '/lapor/kelola/kelola.js',
  '/icons/Icon-192.png',
  '/icons/Icon-512.png',
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then(async (cache) => {
      await Promise.all(
        SHELL_ASSETS.map((url) =>
          cache.add(url).catch((err) => {
            // Tolerate missing assets before UI files are created
            console.warn(`[sw] failed to cache ${url}:`, err);
          })
        )
      );
    })
  );
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(
        keys.map((key) => {
          if (key !== CACHE_NAME && key.startsWith('lapor-')) {
            return caches.delete(key);
          }
        })
      )
    )
  );
  self.clients.claim();
});

self.addEventListener('fetch', (event) => {
  const url = new URL(event.request.url);

  // Network-only for any request to *.supabase.co
  if (url.hostname.endsWith('.supabase.co') || url.hostname === 'supabase.co') {
    return;
  }

  // Only handle GET requests
  if (event.request.method !== 'GET') {
    return;
  }

  // Navigation requests: try cache first, then network with offline fallback to cached /lapor/
  if (event.request.mode === 'navigate') {
    event.respondWith(
      caches.match(event.request).then((cached) => {
        if (cached) {
          return cached;
        }
        return fetch(event.request).catch(() =>
          caches.match('/lapor/').then((res) => res || caches.match('/lapor/index.html'))
        );
      })
    );
    return;
  }

  // Cache-first for app shell assets
  event.respondWith(
    caches.match(event.request).then((cached) => {
      if (cached) {
        return cached;
      }
      return fetch(event.request).then((response) => {
        if (response && response.status === 200 && event.request.url.startsWith(self.location.origin)) {
          const clone = response.clone();
          caches.open(CACHE_NAME).then((cache) => cache.put(event.request, clone));
        }
        return response;
      });
    })
  );
});
