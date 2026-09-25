import { PGlite } from "@electric-sql/pglite";
import {
  type Rpc,
  type RpcArgs,
  type SubscriptionStore,
  subscriptionStore,
} from "../../supabase/functions/_shared/subscriptions.ts";

const migrations = new URL("../../supabase/migrations/", import.meta.url);

export function migrationNames(): string[] {
  return [...Deno.readDirSync(migrations)]
    .map((entry) => entry.name)
    .filter((name) => name.endsWith(".sql"))
    .sort();
}

export async function migratedDatabase(
  beforeMigration: (name: string, db: PGlite) => Promise<void> = () => Promise.resolve(),
): Promise<PGlite> {
  const db = new PGlite();
  await db.exec(`
    create role anon;
    create role authenticated;
    create role service_role;
    alter default privileges in schema public
      grant all on tables to anon, authenticated, service_role;
    alter default privileges in schema public
      grant all on functions to anon, authenticated, service_role;
  `);
  for (const name of migrationNames()) {
    await beforeMigration(name, db);
    await db.exec(await Deno.readTextFile(new URL(name, migrations)));
  }
  return db;
}

function plain(value: unknown): unknown {
  return value instanceof Date ? value.toISOString() : value;
}

function plainRow(row: Record<string, unknown>): Record<string, unknown> {
  return Object.fromEntries(Object.entries(row).map(([key, value]) => [key, plain(value)]));
}

function namedCall(name: string, args: RpcArgs): { call: string; values: unknown[] } {
  const keys = Object.keys(args);
  const params = keys.map((key, index) => `${key} => $${index + 1}`).join(", ");
  return { call: `public.${name}(${params})`, values: keys.map((key) => args[key]) };
}

export function pgliteRpc(db: PGlite): Rpc {
  return {
    async scalar(name, args) {
      const { call, values } = namedCall(name, args);
      const result = await db.query<{ value: unknown }>(`select ${call} as value`, values);
      return plain(result.rows[0]?.value);
    },
    async rows(name, args) {
      const { call, values } = namedCall(name, args);
      const result = await db.query<Record<string, unknown>>(`select * from ${call}`, values);
      return result.rows.map(plainRow);
    },
  };
}

export interface TestDatabase {
  db: PGlite;
  store: SubscriptionStore;
  reset(): Promise<void>;
  subscription(originalTransactionId: string): Promise<Record<string, unknown> | null>;
}

export async function testDatabase(): Promise<TestDatabase> {
  const db = await migratedDatabase();
  return {
    db,
    store: subscriptionStore(pgliteRpc(db)),
    reset: async () => {
      await db.exec("delete from public.subscriptions;");
    },
    subscription: async (originalTransactionId) => {
      const result = await db.query<Record<string, unknown>>(
        "select * from public.subscriptions where original_transaction_id = $1",
        [originalTransactionId],
      );
      const row = result.rows[0];
      return row ? plainRow(row) : null;
    },
  };
}
