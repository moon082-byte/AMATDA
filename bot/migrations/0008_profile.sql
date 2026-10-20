-- 2026-10: 프로필(닉네임#태그·사진·자기소개)과 앱 알림함. 한 번만 실행: npm run db:migrate:profile
ALTER TABLE users ADD COLUMN nickname TEXT;                 -- 닉네임 (2~12자, 처음 로그인할 때 정함)
ALTER TABLE users ADD COLUMN tag TEXT;                      -- 닉네임 뒤 4자리 고유 번호 (닉네임을 바꿔도 유지)
ALTER TABLE users ADD COLUMN bio TEXT;                      -- 자기소개
ALTER TABLE users ADD COLUMN avatar TEXT;                   -- 프로필 사진 (data:image/jpeg;base64,..., 200KB 이하)
ALTER TABLE users ADD COLUMN avatar_updated_at INTEGER;
CREATE UNIQUE INDEX IF NOT EXISTS users_nickname_tag ON users (lower(nickname), tag);

-- 앱 알림함: 다른 기기에서 바꾼 할 일, 보낸 리마인더 (계정당 최근 200개·60일까지)
CREATE TABLE IF NOT EXISTS notifications (
  id         TEXT PRIMARY KEY,
  user_id    TEXT NOT NULL,
  kind       TEXT NOT NULL,                   -- task_added, task_edited, task_deleted, task_done, task_reopened, tasks_changed, reminder
  title      TEXT NOT NULL,
  body       TEXT,
  target     TEXT,                            -- 누르면 열 항목 (task:<id>, routine:<id>), 없으면 NULL
  device     TEXT,                            -- 이 변경을 올린 기기 (그 기기의 알림함에는 보이지 않음), 리마인더는 NULL
  created_at INTEGER NOT NULL,
  read_at    INTEGER                          -- 읽은 시각 (NULL이면 안 읽음)
);
CREATE INDEX IF NOT EXISTS notifications_user ON notifications (user_id, created_at);
