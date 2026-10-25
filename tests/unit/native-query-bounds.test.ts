import { test } from 'node:test';
import assert from 'node:assert/strict';
import type { SQLInputValue } from 'node:sqlite';
import { d1Fixture } from '../helpers/d1.ts';
import { database } from '../../src/lib/server/db/index.ts';
import { syncStatus } from '../../src/lib/server/trakt-sync.ts';
import { addManualTitle, getTitle } from '../../src/lib/server/library.ts';
import { watchCard } from '../../src/lib/server/dashboard.ts';

function observe(f: ReturnType<typeof d1Fixture>) {
  const queries: { sql: string; values: SQLInputValue[] }[] = [];
  const binding = new Proxy(f.binding, {
    get(target, property, receiver) {
      if (property === 'prepare')
        return (sql: string) => {
          const query = { sql, values: [] as SQLInputValue[] };
          queries.push(query);
          const prepared = target.prepare(sql);
          return new Proxy(prepared, {
            get(statement, key, original) {
              if (key === 'bind')
                return (...values: SQLInputValue[]) => {
                  query.values = values;
                  return statement.bind(...values);
                };
              return Reflect.get(statement, key, original);
            }
          });
        };
      return Reflect.get(target, property, receiver);
    }
  });
  return { db: database(binding), queries };
}
function requireBoundedPlan(f: ReturnType<typeof d1Fixture>, query: { sql: string; values: SQLInputValue[] }, index: string) {
  assert.match(query.sql, /\blimit\s+\?/i, 'A first-row API must bound the actual SQL statement');
  assert.equal(query.values.at(-1), 1);
  const plan = f.sqlite.prepare('EXPLAIN QUERY PLAN ' + query.sql).all(...query.values)
    .map((row) => String(row.detail)).join('\n');
  assert.match(plan, new RegExp(index));
  assert.doesNotMatch(plan, /TEMP B-TREE/, 'The first result must not sort the entire history');
}

test('native Trakt status selects one latest review without scanning and sorting every old run', async (t) => {
  const f = d1Fixture(); t.after(f.close);
  const insert = f.sqlite.prepare(`INSERT INTO trakt_sync_runs(id,account_id,state,stage,rating_mode,created_at,updated_at)
    VALUES(?,'fixture','complete','done','round',?,?)`);
  for (let i = 0; i < 1000; i++) {
    const date = new Date(Date.UTC(2026, 0, 1, 0, i)).toISOString();
    insert.run('run-' + String(i).padStart(4, '0'), date, date);
  }
  const { db, queries } = observe(f);
  assert.equal((await syncStatus(db)).run?.id, 'run-0999');
  const query = queries.find((q) => q.sql.includes('trakt_sync_runs') && /order by/i.test(q.sql));
  assert.ok(query); requireBoundedPlan(f, query, 'trakt_runs_recent');
});

test('native movie progress finds the latest watch without sorting all prior rewatches', async (t) => {
  const f = d1Fixture(); t.after(f.close);
  await addManualTitle(f.db, { id: 'native-movie', name: 'Native movie', category: 'movie', status: 'watching' });
  const insert = f.sqlite.prepare(`INSERT INTO watch_events(id,operation_id,title_id,episode_id,watched_at,recorded_at,revoked_at,origin)
    VALUES(?,?,'native-movie',NULL,NULL,?,NULL,'manual')`);
  for (let i = 0; i < 600; i++)
    insert.run('watch-' + i, 'operation-' + i, new Date(Date.UTC(2026, 0, 1, 0, i)).toISOString());
  const { db, queries } = observe(f);
  const card = await watchCard(db, await getTitle(db, 'native-movie'), '2026-10-25');
  assert.equal(card.previous?.id, 'watch-599'); assert.equal(card.progress.watched, 1);
  const query = queries.find((q) => q.sql.includes('watch_events') && /order by/i.test(q.sql));
  assert.ok(query); requireBoundedPlan(f, query, 'watch_movie_latest');
});
