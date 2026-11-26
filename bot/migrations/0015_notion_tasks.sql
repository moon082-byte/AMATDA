-- 노션 연동 범용화: 할일용 DB 추가, DB마다 속성 매핑을 사용자가 고른다
ALTER TABLE users ADD COLUMN notion_task_db TEXT;
ALTER TABLE users ADD COLUMN notion_task_map TEXT; -- JSON {title, done?: {prop, type, doneValue?, todoValue?}, date?, content?}
ALTER TABLE users ADD COLUMN notion_memo_map TEXT; -- JSON {title, content?, date?, status?: {prop, type, value}}

-- 할 일도 메모처럼 노션 페이지와 연결한다
ALTER TABLE tasks ADD COLUMN notion_page_id TEXT;
ALTER TABLE tasks ADD COLUMN notion_dirty INTEGER NOT NULL DEFAULT 0;
ALTER TABLE tasks ADD COLUMN notion_tries INTEGER NOT NULL DEFAULT 0;
CREATE INDEX IF NOT EXISTS tasks_notion ON tasks (notion_dirty);

-- 이미 메모 DB를 연결한 계정: 예전 고정 매핑(이름·내용·상태=정리 대기)을 그대로 옮긴다
UPDATE users SET notion_memo_map = json_object(
  'title', '이름', 'content', '내용',
  'status', json_object('prop', '상태', 'type', COALESCE(notion_status_type, 'select'), 'value', '정리 대기'))
WHERE notion_memo_db IS NOT NULL AND notion_memo_map IS NULL;

-- 실패 이유(설정 화면에 보여줌)와 마지막으로 보낸 본문 지문(본문이 그대로면 속성만 고쳐 노션 호출을 줄인다)
ALTER TABLE tasks ADD COLUMN notion_error TEXT;
ALTER TABLE tasks ADD COLUMN notion_body_hash TEXT;
ALTER TABLE memos ADD COLUMN notion_body_hash TEXT;
