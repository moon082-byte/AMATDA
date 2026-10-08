// 테스트용 D1: Node 내장 SQLite에 실제 스키마·마이그레이션을 적용한 메모리 DB
import { readFileSync } from 'node:fs';
import { DatabaseSync } from 'node:sqlite';

const FILES = [
  'schema.sql',
  'migrations/0002_accounts.sql',
  'migrations/0003_pin.sql',
  'migrations/0004_tg_room_url.sql',
  'migrations/0005_nag.sql',
];

export function fakeD1() {
  const db = new DatabaseSync(':memory:');
  for (const f of FILES) db.exec(readFileSync(new URL(`../../${f}`, import.meta.url), 'utf8'));
  const prepare = (sql) => {
    let params = [];
    const stmt = {
      bind(...p) {
        params = p;
        return stmt;
      },
      all: async () => ({ results: db.prepare(sql).all(...params) }),
      first: async () => db.prepare(sql).get(...params) ?? null,
      run: async () => ({ meta: { changes: Number(db.prepare(sql).run(...params).changes) } }),
    };
    return stmt;
  };
  return {
    prepare,
    batch: async (list) => {
      for (const s of list) await s.run();
    },
    exec: (sql) => db.exec(sql),
    rows: (sql) => db.prepare(sql).all(),
  };
}
