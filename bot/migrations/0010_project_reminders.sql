-- 2026-10: 프로젝트 리마인더 (팀장이 프로젝트에 건 알림 시각). 한 번만 실행: npm run db:migrate:projectreminders
-- 시각이 되면 팀장과 그 프로젝트에 진행 중 업무가 있는 담당자에게 알림함·텔레그램·시스템 알림으로 보낸다.
CREATE TABLE IF NOT EXISTS project_reminders (
  project_id TEXT NOT NULL,
  room_id    TEXT NOT NULL,
  fire_at    INTEGER NOT NULL,                -- 알림 시각 (epoch ms)
  sent       INTEGER NOT NULL DEFAULT 0,      -- 1이면 보냄
  PRIMARY KEY (project_id, fire_at)
);
CREATE INDEX IF NOT EXISTS project_reminders_due ON project_reminders (sent, fire_at);
