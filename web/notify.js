// 앱(Dart)에서 부르는 브라우저 알림 헬퍼: window.amatdaNotification
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
  };
})();
