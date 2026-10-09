-- 2026-10: 관리자 화면에서 관리하는 허용 이메일. 한 번만 실행: npm run db:migrate:allowed
-- 서버 비밀값 ALLOWED_EMAILS·OWNER_EMAIL의 이메일도 계속 허용한다 (관리자가 잠기지 않게, 화면에서는 '서버 설정'으로 표시)
CREATE TABLE IF NOT EXISTS allowed_emails (
  email      TEXT PRIMARY KEY,                -- 소문자
  added_by   TEXT,                            -- 추가한 관리자 users.id
  created_at INTEGER NOT NULL
);
