-- 메모 (기기 간 동기화, 다른 사용자 데이터 표와 같은 모양) + 노션 연동
CREATE TABLE IF NOT EXISTS memos (
  user_id TEXT NOT NULL, id TEXT NOT NULL, parent_id TEXT, position INTEGER NOT NULL DEFAULT 0,
  data TEXT NOT NULL, deleted INTEGER NOT NULL DEFAULT 0, version INTEGER NOT NULL, updated_at INTEGER NOT NULL,
  notion_page_id TEXT,                     -- 노션 1_Inbox에 만든 페이지
  notion_dirty   INTEGER NOT NULL DEFAULT 0, -- 1이면 노션에 반영할 변경이 있음 (1분마다 다시 시도)
  notion_tries   INTEGER NOT NULL DEFAULT 0, -- 연속 실패 횟수 (많이 실패하면 다음 수정 때까지 쉰다)
  PRIMARY KEY (user_id, id)
);
CREATE INDEX IF NOT EXISTS memos_sync ON memos (user_id, version);
CREATE INDEX IF NOT EXISTS memos_notion ON memos (notion_dirty);

-- 노션 연동 설정 (토큰은 서버 비밀값으로 암호화해 저장하고 앱에는 돌려주지 않는다)
ALTER TABLE users ADD COLUMN notion_enabled INTEGER NOT NULL DEFAULT 0;
ALTER TABLE users ADD COLUMN notion_token TEXT;
ALTER TABLE users ADD COLUMN notion_memo_db TEXT;
ALTER TABLE users ADD COLUMN notion_status_type TEXT; -- 메모 DB '상태' 속성 종류 (select 또는 status)
