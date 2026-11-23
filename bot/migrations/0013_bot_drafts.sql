-- 텔레그램 봇 일정 관리: 확인 버튼을 누르기 전의 할 일 추가·수정 내용과, 수정할 내용을 기다리는 상태
-- (버튼 데이터는 64바이트까지라 할 일 이름을 담을 수 없어 여기에 두고 짧은 id만 버튼에 넣는다. 하루 지나면 지운다)
CREATE TABLE IF NOT EXISTS bot_drafts (
  id         TEXT PRIMARY KEY,
  user_id    TEXT NOT NULL,
  chat_id    INTEGER NOT NULL,
  kind       TEXT NOT NULL,      -- add: 추가 확인 대기 | edit: 수정 확인 대기 | wait: 수정할 내용 입력 대기
  item_kind  TEXT,               -- t: 할 일, r: 루틴 (수정할 때)
  item_id    TEXT,
  data       TEXT,               -- 추가·수정할 내용 JSON
  created_at INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS bot_drafts_chat ON bot_drafts (chat_id, kind);
