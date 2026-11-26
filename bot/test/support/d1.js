// 테스트용 D1: Node 내장 SQLite에 실제 스키마·마이그레이션을 적용한 메모리 DB
import { readFileSync } from 'node:fs';
import { DatabaseSync } from 'node:sqlite';

const FILES = [
  'schema.sql',
  'migrations/0002_accounts.sql',
  'migrations/0003_pin.sql',
  'migrations/0004_tg_room_url.sql',
  'migrations/0005_nag.sql',
  'migrations/0006_allowed_emails.sql',
  'migrations/0007_push.sql',
  'migrations/0008_profile.sql',
  'migrations/0009_projects.sql',
  'migrations/0010_project_reminders.sql',
  'migrations/0011_task_review.sql',
  'migrations/0012_overdue.sql',
  'migrations/0013_bot_drafts.sql',
  'migrations/0014_memos.sql',
  'migrations/0015_notion_tasks.sql',
];

/** 실제 D1처럼 UNION 등으로 이은 SELECT는 5개까지만 허용한다 (SQLite 기본값 500과 다르다) */
const D1_MAX_COMPOUND = 5;
function checkCompound(sql) {
  const terms = (sql.match(/\b(UNION|INTERSECT|EXCEPT)\b/gi) ?? []).length + 1;
  if (terms > D1_MAX_COMPOUND) throw new Error('D1_ERROR: too many terms in compound SELECT: SQLITE_ERROR');
}

export function fakeD1() {
  const db = new DatabaseSync(':memory:');
  for (const f of FILES) db.exec(readFileSync(new URL(`../../${f}`, import.meta.url), 'utf8'));
  const prepare = (sql) => {
    checkCompound(sql);
    let params = [];
    const stmt = {
      bind(...p) {
        params = p;
        return stmt;
      },
      all: async () => ({ results: db.prepare(sql).all(...params) }),
      first: async () => db.prepare(sql).get(...params) ?? null,
      run: async () => ({ meta: { changes: Number(db.prepare(sql).run(...params).changes) } }),
      // batch용: 실제 D1처럼 문장마다 { results }를 돌려준다
      inBatch: () => ({ results: /^\s*(SELECT|WITH)/i.test(sql) ? db.prepare(sql).all(...params) : (db.prepare(sql).run(...params), []) }),
    };
    return stmt;
  };
  return {
    prepare,
    batch: async (list) => list.map((s) => s.inBatch()),
    exec: (sql) => db.exec(sql),
    rows: (sql) => db.prepare(sql).all(),
  };
}
