-- 2026-10: 끈질긴 알림 ([✅ 확인]을 누를 때까지 5분마다 최대 3번 더). 한 번만 실행: npm run db:migrate:nag
ALTER TABLE reminders ADD COLUMN ack_id TEXT;                               -- 확인 버튼·앱 링크에 쓰는 값 (서버 비밀값으로 만든 HMAC)
ALTER TABLE reminders ADD COLUMN acked INTEGER NOT NULL DEFAULT 0;          -- 1이면 확인함 (다시 보내지 않음)
ALTER TABLE reminders ADD COLUMN repeats INTEGER NOT NULL DEFAULT 0;        -- 다시 보낸 횟수
ALTER TABLE reminders ADD COLUMN next_at INTEGER;                           -- 다음에 다시 보낼 시각 (NULL이면 더 보내지 않음)
CREATE INDEX IF NOT EXISTS reminders_ack ON reminders (ack_id);
ALTER TABLE users ADD COLUMN nag_enabled INTEGER NOT NULL DEFAULT 1;        -- 끈질긴 알림 사용 (기본 켬)
