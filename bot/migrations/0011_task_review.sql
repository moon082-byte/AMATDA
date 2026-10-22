-- 2026-10: 세부업무 검토 단계. 한 번만 실행: npm run db:migrate:taskreview
-- 상태: done_at 있음 = 최종완료 / review_at 있음 = 검토중 / 둘 다 없음 = 진행중 (반려하면 review_at을 비운다)
ALTER TABLE project_tasks ADD COLUMN review_at INTEGER;   -- 담당자가 완료 보고(검토 요청)한 시각
