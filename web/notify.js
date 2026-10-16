// 앱(Dart)에서 부르는 브라우저 알림·푸시 구독 헬퍼: window.amatdaNotification
(function () {
  const supported = 'Notification' in window;
  const swReady = 'serviceWorker' in navigator
    ? navigator.serviceWorker.register('notify_sw.js')
        .then(() => navigator.serviceWorker.ready)
        .catch(() => null)
    : Promise.resolve(null);

  window.amatdaNotification = {
    supported: () => supported,

    // 'granted' | 'denied' | 'default' | 'unsupported'
    permission: () => (supported ? Notification.permission : 'unsupported'),

    requestPermission: async () => {
      if (!supported) return 'unsupported';
      try {
        return await Notification.requestPermission();
      } catch (e) {
        return Notification.permission;
      }
    },

    show: async (title, body, tag) => {
      if (!supported || Notification.permission !== 'granted') return false;
      const options = { body, tag, icon: 'icons/Icon-192.png', badge: 'icons/Icon-192.png' };
      try {
        const registration = await swReady;
        if (registration) {
          await registration.showNotification(title, options);
          return true;
        }
      } catch (e) { /* 서비스 워커가 없으면 아래 방식으로 시도 */ }
      try {
        new Notification(title, options);
        return true;
      } catch (e) {
        return false;
      }
    },

    isHidden: () => document.visibilityState === 'hidden',

    // ---- 시스템 알림 (Web Push): 앱을 닫아 둬도 서버가 이 기기로 알림을 보낸다 ----

    pushSupported: () => supported && 'serviceWorker' in navigator && 'PushManager' in window,

    // 아이폰·아이패드 사파리 탭에서 열었는지 (홈 화면에 추가해야 푸시를 쓸 수 있다)
    needsHomeScreen: () => {
      const ios = /iPad|iPhone|iPod/.test(navigator.userAgent) ||
        (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
      const standalone = window.matchMedia('(display-mode: standalone)').matches ||
        navigator.standalone === true;
      return ios && !standalone;
    },

    // 이 기기의 현재 구독 (없으면 ''): JSON 문자열 {endpoint, keys: {p256dh, auth}}
    pushSubscription: async () => {
      const registration = await swReady;
      const sub = registration && await registration.pushManager.getSubscription();
      return sub ? JSON.stringify(sub.toJSON()) : '';
    },

    // 권한을 묻고 구독한다. 성공하면 구독 JSON, 실패하면 'error:<denied|default|sw|이유>'.
    // 아이폰은 사용자가 누른 직후에만 권한을 물을 수 있으므로 권한 요청을 가장 먼저 한다.
    pushSubscribe: async (key) => {
      if (!supported) return 'error:unsupported';
      let permission;
      try {
        permission = await Notification.requestPermission();
      } catch (e) {
        permission = Notification.permission;
      }
      if (permission !== 'granted') return 'error:' + permission;
      const registration = await swReady;
      if (!registration) return 'error:sw';
      const options = { userVisibleOnly: true, applicationServerKey: base64urlBytes(key) };
      try {
        let sub = await registration.pushManager.getSubscription();
        try {
          if (!sub) sub = await registration.pushManager.subscribe(options);
        } catch (e) {
          // 서버 키가 바뀌었으면 예전 구독을 지우고 다시 구독한다
          if (sub) await sub.unsubscribe();
          sub = await registration.pushManager.subscribe(options);
        }
        return JSON.stringify(sub.toJSON());
      } catch (e) {
        return 'error:' + (e && e.message ? e.message : 'subscribe');
      }
    },

    // 구독을 끊고 끊은 주소를 돌려준다 (없으면 '')
    pushUnsubscribe: async () => {
      const registration = await swReady;
      const sub = registration && await registration.pushManager.getSubscription();
      if (!sub) return '';
      const endpoint = sub.endpoint;
      try {
        await sub.unsubscribe();
      } catch (e) { /* 이미 끊긴 구독 */ }
      return endpoint;
    },
  };

  function base64urlBytes(text) {
    const b64 = text.replace(/-/g, '+').replace(/_/g, '/');
    const bin = atob(b64 + '='.repeat((4 - (b64.length % 4)) % 4));
    return Uint8Array.from(bin, (c) => c.charCodeAt(0));
  }
})();
