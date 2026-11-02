-- 2026-11: 기한 지난 세부업무. 한 번만 실행: npm run db:migrate:overdue
-- missed_at: 담당자가 [미완료 처리]한 시각 (완료와 구분, 통계용). 팀장이 마감을 바꾸면 비워서 다시 진행중으로.
-- overdue_notified_at: 마감이 지나 팀장에게 알린 시각 (한 번만). 마감을 바꾸면 비운다.
ALTER TABLE project_tasks ADD COLUMN missed_at INTEGER;
ALTER TABLE project_tasks ADD COLUMN overdue_notified_at INTEGER;
