// 리마인드 알림 표시용 서비스 워커.
// 안드로이드 크롬 등은 페이지에서 직접 알림을 만들 수 없어 서비스 워커를 거쳐야 한다.
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (event) => event.waitUntil(self.clients.claim()));

// 알림을 누르면 열려 있는 앱 창으로 이동하고, 없으면 새로 연다
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.waitUntil((async () => {
    const windows = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
    for (const client of windows) {
      if ('focus' in client) return client.focus();
    }
    if (self.clients.openWindow) return self.clients.openWindow(self.registration.scope);
  })());
});
