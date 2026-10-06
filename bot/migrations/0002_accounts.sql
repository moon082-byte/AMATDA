-- 2026-10: 구글 로그인(멀티유저)과 기기 간 데이터 동기화
-- 이미 만들어 둔 데이터베이스에 한 번만 실행한다: npm run db:migrate:accounts
-- 기존 표(links, reminders)는 그대로 두고 칸·표만 추가한다.

-- 구글 계정으로 가입한 사용자
CREATE TABLE IF NOT EXISTS users (
  id         TEXT PRIMARY KEY,            -- 'u_' + 무작위 (앱 데이터의 user_id)
  google_sub TEXT NOT NULL UNIQUE,        -- 구글 계정 고유 번호
  email      TEXT NOT NULL,
  name       TEXT,
  picture    TEXT,
  version    INTEGER NOT NULL DEFAULT 0,  -- 데이터가 바뀔 때마다 늘어나는 순번 (동기화 기준)
  created_at INTEGER NOT NULL
);

-- 로그인 세션 (토큰 원문은 저장하지 않고 SHA-256 해시만 저장)
CREATE TABLE IF NOT EXISTS sessions (
  token_hash   TEXT PRIMARY KEY,
  user_id      TEXT NOT NULL,
  created_at   INTEGER NOT NULL,
  last_used_at INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS sessions_user ON sessions (user_id);

-- 잠깐 쓰고 버리는 값: 구글 로그인 중 state·PKCE(kind='state'),
-- 로그인 직후 앱이 세션으로 바꿀 일회용 코드(kind='login'), 텔레그램 연결 코드(kind='tg')
CREATE TABLE IF NOT EXISTS oauth_states (
  state      TEXT PRIMARY KEY,
  kind       TEXT NOT NULL,
  verifier   TEXT,
  return_to  TEXT,
  user_id    TEXT,
  expires_at INTEGER NOT NULL
);

-- 사용자 데이터: 모든 표가 같은 모양 (user_id, id)가 기본 키.
-- parent_id: 할 일→업무방, 세부 항목·메모→할 일 / position: 화면 순서 / data: 나머지 내용(JSON)
-- deleted=1은 삭제 표시 (다른 기기에도 삭제가 전달되도록 행을 남긴다)
CREATE TABLE IF NOT EXISTS rooms (
  user_id TEXT NOT NULL, id TEXT NOT NULL, parent_id TEXT, position INTEGER NOT NULL DEFAULT 0,
  data TEXT NOT NULL, deleted INTEGER NOT NULL DEFAULT 0, version INTEGER NOT NULL, updated_at INTEGER NOT NULL,
  PRIMARY KEY (user_id, id)
);
CREATE INDEX IF NOT EXISTS rooms_sync ON rooms (user_id, version);

CREATE TABLE IF NOT EXISTS tasks (
  user_id TEXT NOT NULL, id TEXT NOT NULL, parent_id TEXT, position INTEGER NOT NULL DEFAULT 0,
  data TEXT NOT NULL, deleted INTEGER NOT NULL DEFAULT 0, version INTEGER NOT NULL, updated_at INTEGER NOT NULL,
  PRIMARY KEY (user_id, id)
);
CREATE INDEX IF NOT EXISTS tasks_sync ON tasks (user_id, version);

CREATE TABLE IF NOT EXISTS sub_tasks (
  user_id TEXT NOT NULL, id TEXT NOT NULL, parent_id TEXT, position INTEGER NOT NULL DEFAULT 0,
  data TEXT NOT NULL, deleted INTEGER NOT NULL DEFAULT 0, version INTEGER NOT NULL, updated_at INTEGER NOT NULL,
  PRIMARY KEY (user_id, id)
);
CREATE INDEX IF NOT EXISTS sub_tasks_sync ON sub_tasks (user_id, version);

CREATE TABLE IF NOT EXISTS notes (
  user_id TEXT NOT NULL, id TEXT NOT NULL, parent_id TEXT, position INTEGER NOT NULL DEFAULT 0,
  data TEXT NOT NULL, deleted INTEGER NOT NULL DEFAULT 0, version INTEGER NOT NULL, updated_at INTEGER NOT NULL,
  PRIMARY KEY (user_id, id)
);
CREATE INDEX IF NOT EXISTS notes_sync ON notes (user_id, version);

CREATE TABLE IF NOT EXISTS routines (
  user_id TEXT NOT NULL, id TEXT NOT NULL, parent_id TEXT, position INTEGER NOT NULL DEFAULT 0,
  data TEXT NOT NULL, deleted INTEGER NOT NULL DEFAULT 0, version INTEGER NOT NULL, updated_at INTEGER NOT NULL,
  PRIMARY KEY (user_id, id)
);
CREATE INDEX IF NOT EXISTS routines_sync ON routines (user_id, version);

-- 텔레그램 연결을 계정 단위로: 계정 연결은 code = user_id, user_id 칸에도 같은 값
-- (예전 앱이 만든 연결은 user_id가 비어 있고, 주인 계정이 처음 로그인할 때 옮겨진다)
-- 알림 일정(reminders)은 code 칸으로 연결을 가리키므로 계정 연결이면 code가 곧 user_id다.
ALTER TABLE links ADD COLUMN user_id TEXT;
