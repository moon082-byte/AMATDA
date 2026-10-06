-- 2026-10: 알림 메시지 아래 링크 버튼([앱에서 보기], 업무 링크) 저장 칸 추가
-- 이미 만들어 둔 데이터베이스에 한 번만 실행한다: npm run db:migrate
ALTER TABLE reminders ADD COLUMN buttons TEXT;
