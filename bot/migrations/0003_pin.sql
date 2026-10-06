-- 2026-10: 2차 비밀번호(4자리 PIN). 이미 만든 데이터베이스에 한 번만 실행: npm run db:migrate:pin
-- PIN 원문은 저장하지 않는다: pin_hash = HMAC-SHA256(서버 비밀키 PIN_PEPPER, pin_salt + ':' + PIN)
ALTER TABLE users ADD COLUMN pin_hash TEXT;                                 -- NULL이면 PIN 사용 안 함
ALTER TABLE users ADD COLUMN pin_salt TEXT;
ALTER TABLE users ADD COLUMN pin_failed INTEGER NOT NULL DEFAULT 0;         -- 연속으로 틀린 횟수
ALTER TABLE users ADD COLUMN pin_locked_until INTEGER NOT NULL DEFAULT 0;   -- 잠금이 풀리는 시각 (epoch ms)
ALTER TABLE users ADD COLUMN pin_lock_level INTEGER NOT NULL DEFAULT 0;     -- 지금까지 잠긴 횟수 (0: 다음 잠금 1분, 1 이상: 30분)
ALTER TABLE users ADD COLUMN pin_reset_hash TEXT;                           -- 텔레그램으로 보낸 재설정 코드의 해시
ALTER TABLE users ADD COLUMN pin_reset_expires INTEGER NOT NULL DEFAULT 0;
ALTER TABLE users ADD COLUMN pin_reset_tries INTEGER NOT NULL DEFAULT 0;
ALTER TABLE sessions ADD COLUMN pin_ok_at INTEGER;                          -- 이 로그인에서 PIN을 확인한 시각
