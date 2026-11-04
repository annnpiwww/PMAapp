// Stub self-destruct untuk service worker lama.
// Web sekarang dibuild dengan `--pwa-strategy=none` supaya teknisi SELALU dapat
// JS terbaru. File ini menggantikan SW lama, menghapus cache-nya, lalu melepas
// registrasinya agar tidak ada lagi versi lama yang nyangkut di PWA.
self.addEventListener('install', () => self.skipWaiting());

self.addEventListener('activate', (event) => {
  event.waitUntil(
    (async () => {
      const keys = await caches.keys();
      await Promise.all(keys.map((k) => caches.delete(k)));
      await self.registration.unregister();
      const clientList = await self.clients.matchAll({ type: 'window' });
      clientList.forEach((client) => client.navigate(client.url));
    })(),
  );
});
