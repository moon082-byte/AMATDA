-- 2026-10: 프로젝트방 (여러 사람이 함께 쓰는 공유 데이터). 한 번만 실행: npm run db:migrate:projects
-- 구조: 프로젝트방(이름·목표·텔레그램·팀원) → 프로젝트(마감) → 세부업무(담당자·마감·완료)
-- 권한은 서버가 요청마다 project_members.role 로 검사한다 (leader: 팀장, member: 팀원)
CREATE TABLE IF NOT EXISTS project_rooms (
  id           TEXT PRIMARY KEY,
  name         TEXT NOT NULL,
  goal         TEXT NOT NULL DEFAULT '',
  telegram_url TEXT NOT NULL DEFAULT '',
  leader_id    TEXT NOT NULL,                -- users.id
  created_at   INTEGER NOT NULL,
  updated_at   INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS project_members (
  room_id    TEXT NOT NULL,
  user_id    TEXT NOT NULL,
  role       TEXT NOT NULL,                  -- leader | member
  status     TEXT NOT NULL,                  -- invited(초대만 받음) | active(수락함)
  invited_by TEXT,
  created_at INTEGER NOT NULL,
  PRIMARY KEY (room_id, user_id)
);
CREATE INDEX IF NOT EXISTS project_members_user ON project_members (user_id, status);

CREATE TABLE IF NOT EXISTS projects (
  id         TEXT PRIMARY KEY,
  room_id    TEXT NOT NULL,
  name       TEXT NOT NULL,
  due_at     INTEGER,                         -- 마감 (epoch ms, 없으면 NULL)
  position   INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS projects_room ON projects (room_id);

CREATE TABLE IF NOT EXISTS project_tasks (
  id          TEXT PRIMARY KEY,
  project_id  TEXT NOT NULL,
  room_id     TEXT NOT NULL,
  title       TEXT NOT NULL,
  assignee_id TEXT,                           -- 담당자 users.id (없으면 미배정)
  due_at      INTEGER,
  done_at     INTEGER,                        -- 완료 시각 (NULL이면 진행 중)
  position    INTEGER NOT NULL DEFAULT 0,
  created_at  INTEGER NOT NULL,
  updated_at  INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS project_tasks_project ON project_tasks (project_id);
CREATE INDEX IF NOT EXISTS project_tasks_room ON project_tasks (room_id);
CREATE INDEX IF NOT EXISTS project_tasks_assignee ON project_tasks (assignee_id, done_at);
