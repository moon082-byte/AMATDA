// 리마인드 알림 표시용 서비스 워커.
// - 안드로이드 크롬 등은 페이지에서 직접 알림을 만들 수 없어 서비스 워커를 거쳐야 한다.
// - 시스템 알림(Web Push): 앱을 닫아 둬도 봇 서버가 보낸 푸시를 받아 알림을 띄운다.
//   내용은 {title, body, tag, url} (봇 서버 push.js의 pushMessage)
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (event) => event.waitUntil(self.clients.claim()));

self.addEventListener('push', (event) => {
  let data = {};
  try {
    data = event.data ? event.data.json() : {};
  } catch (e) {
    data = { body: event.data ? event.data.text() : '' };
  }
  // 아이폰은 받은 푸시마다 반드시 알림을 띄워야 한다 (안 띄우면 구독이 끊길 수 있다)
  event.waitUntil(self.registration.showNotification(data.title || '🔔 아맞다 알림', {
    body: data.body || '',
    tag: data.tag,
    icon: 'icons/Icon-192.png',
    badge: 'icons/Icon-192.png',
    data: { url: data.url || null },
  }));
});

// 알림을 누르면 해당 할 일 화면(url)을 연다. 열려 있는 앱 창이 있으면 그 창에서, 없으면 새 창으로.
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const url = (event.notification.data && event.notification.data.url) || null;
  event.waitUntil((async () => {
    const windows = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
    for (const client of windows) {
      if (!('focus' in client)) continue;
      if (url && 'navigate' in client) {
        try {
          const moved = await client.navigate(url);
          return (moved || client).focus();
        } catch (e) { /* 이 서비스 워커가 관리하지 않는 창이면 아래에서 새 창으로 연다 */ }
      } else if (!url) {
        return client.focus();
      }
    }
    if (self.clients.openWindow) return self.clients.openWindow(url || self.registration.scope);
  })());
});
