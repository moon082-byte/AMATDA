-- 아맞다 텔레그램 알림봇 데이터베이스 (Cloudflare D1 / SQLite)

-- 앱 연결 코드 ↔ 텔레그램 대화방
CREATE TABLE IF NOT EXISTS links (
  code       TEXT PRIMARY KEY,           -- 앱이 만든 무작위 연결 코드 (앱 쪽 비밀값)
  chat_id    INTEGER NOT NULL,           -- 알림을 보낼 텔레그램 대화방
  chat_name  TEXT,                       -- 연결된 사용자 이름 (앱 화면 표시용)
  created_at INTEGER NOT NULL            -- 연결 시각 (epoch ms)
);
CREATE INDEX IF NOT EXISTS links_chat ON links (chat_id);

-- 앱이 올려 둔 알림 일정
CREATE TABLE IF NOT EXISTS reminders (
  code    TEXT NOT NULL,                 -- links.code
  key     TEXT NOT NULL,                 -- 알림 고유 키 (같은 알림 중복 발송 방지)
  fire_at INTEGER NOT NULL,              -- 보낼 시각 (epoch ms)
  due_at  INTEGER NOT NULL,              -- 마감 시각 (epoch ms, 오래 지난 알림 정리용)
  text    TEXT NOT NULL,                 -- 보낼 메시지 (앱이 만들어 보냄)
  buttons TEXT,                          -- 메시지 아래 링크 버튼 JSON [{text, url}] (없으면 NULL)
  sent    INTEGER NOT NULL DEFAULT 0,    -- 1이면 이미 보냄
  PRIMARY KEY (code, key)
);
CREATE INDEX IF NOT EXISTS reminders_due ON reminders (sent, fire_at);
