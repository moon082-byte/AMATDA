-- 2026-10: 사용자별 텔레그램 업무방 링크 (알림 메시지의 [텔레그램 업무방] 줄과 버튼). 한 번만 실행: npm run db:migrate:tgroom
ALTER TABLE users ADD COLUMN tg_room_url TEXT;                              -- NULL이면 그 줄과 버튼을 빼고 보낸다
