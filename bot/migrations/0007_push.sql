-- 2026-10: 휴대폰·PC 시스템 알림 (Web Push). 한 번만 실행: npm run db:migrate:push
-- 기기(브라우저)마다 푸시 구독 하나. 같은 계정의 모든 구독 기기로 알림을 보낸다.
CREATE TABLE IF NOT EXISTS push_subscriptions (
  endpoint   TEXT PRIMARY KEY,               -- 브라우저 푸시 서비스 주소 (기기마다 다름)
  user_id    TEXT NOT NULL,                  -- users.id (알림 일정 reminders.code와 같은 값)
  p256dh     TEXT NOT NULL,                  -- 메시지 암호화용 기기 공개키 (base64url)
  auth       TEXT NOT NULL,                  -- 메시지 암호화용 기기 비밀값 (base64url)
  created_at INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS push_subscriptions_user ON push_subscriptions (user_id);
ALTER TABLE reminders ADD COLUMN push_sent INTEGER NOT NULL DEFAULT 0;     -- 1이면 푸시로 보냄 (텔레그램 sent와 따로)
CREATE INDEX IF NOT EXISTS reminders_push ON reminders (push_sent, fire_at);
