import { assertEquals, assertThrows } from "@std/assert";
import { ApiError } from "../supabase/functions/_shared/respond.ts";

type Handler = (req: Request) => Promise<Response>;

const served: { handler?: Handler } = {};
const realServe = Object.getOwnPropertyDescriptor(Deno, "serve")!;
Object.defineProperty(Deno, "serve", {
  configurable: true,
  value: (handler: Handler) => {
    served.handler = handler;
  },
});
const { configFrom } = await import("../supabase/functions/config/index.ts");
Object.defineProperty(Deno, "serve", realServe);

function callConfig(init: RequestInit = {}): Promise<Response> {
  if (!served.handler) throw new Error("config/index.ts did not register a handler");
  return served.handler(new Request("https://corbie.test/functions/v1/config", init));
}

function closedLocalPort(): number {
  const listener = Deno.listen({ hostname: "127.0.0.1", port: 0 });
  const { port } = listener.addr;
  listener.close();
  return port;
}

type ConfigRows = { key: string; value: unknown }[];

function rows(values: Record<string, unknown>): ConfigRows {
  return Object.entries(values).map(([key, value]) => ({ key, value }));
}

function read(values: Record<string, unknown>) {
  return { data: rows(values), error: null };
}

function assertInternal(input: Parameters<typeof configFrom>[0]): void {
  const error = assertThrows(() => configFrom(input), ApiError) as ApiError;
  assertEquals(error.code, "internal");
  assertEquals(error.status, 500);
}

Deno.test("stored values are returned as they are", () => {
  assertEquals(
    configFrom(read({ monetization_enabled: false, monetization_v2_enabled: true, free_days: 5 })),
    { monetizationEnabled: false, monetizationV2Enabled: true, freeDays: 5 },
  );
  assertEquals(
    configFrom(read({ monetization_enabled: true, monetization_v2_enabled: false, free_days: 3 })),
    { monetizationEnabled: true, monetizationV2Enabled: false, freeDays: 3 },
  );
});

Deno.test("the two monetization keys never borrow each other's value", () => {
  assertEquals(configFrom(read({ monetization_enabled: false })).monetizationV2Enabled, true);
  assertEquals(configFrom(read({ monetization_v2_enabled: false })).monetizationEnabled, true);
});

Deno.test("missing rows mean monetization is on and the window is three days", () => {
  assertEquals(configFrom({ data: null, error: null }), {
    monetizationEnabled: true,
    monetizationV2Enabled: true,
    freeDays: 3,
  });
  assertEquals(configFrom(read({})).freeDays, 3);
});

Deno.test("zero free days is a valid answer", () => {
  assertEquals(configFrom(read({ free_days: 0 })).freeDays, 0);
});

Deno.test("a database error is an internal error, never a default", () => {
  assertInternal({ data: null, error: { message: "connection refused" } });
  assertInternal({
    data: rows({ monetization_v2_enabled: false }),
    error: { message: "partial read" },
  });
  assertInternal({
    data: rows({ monetization_enabled: true }),
    error: { message: "partial read" },
  });
});

Deno.test("a flag that is not a JSON boolean is an internal error", () => {
  for (const key of ["monetization_enabled", "monetization_v2_enabled"]) {
    for (const value of ["true", "false", 1, 0, null, {}, [], [true], { enabled: true }]) {
      assertInternal(read({ [key]: value }));
    }
  }
});

Deno.test("free days that are not a whole number of days are an internal error", () => {
  for (const value of ["3", 2.5, -1, true, null, {}, [3]]) {
    assertInternal(read({ free_days: value }));
  }
});

Deno.test("the endpoint refuses anything but GET with 405", async () => {
  for (const method of ["POST", "PUT", "DELETE", "OPTIONS"]) {
    const response = await callConfig({ method });
    assertEquals(response.status, 405, method);
    assertEquals((await response.json()).error, "invalid_request");
  }
});

Deno.test("an unreachable database answers 500 internal, not a flag", async () => {
  Deno.env.set("SUPABASE_URL", `http://127.0.0.1:${closedLocalPort()}`);
  Deno.env.set("SUPABASE_SERVICE_ROLE_KEY", "test-service-role-key");
  Deno.env.set("RATE_LIMIT_SALT", "test-salt");
  try {
    const response = await callConfig();
    const body = await response.json();
    assertEquals(response.status, 500);
    assertEquals(body.error, "internal");
    assertEquals("monetizationEnabled" in body, false);
    assertEquals("monetizationV2Enabled" in body, false);
    assertEquals("freeDays" in body, false);
  } finally {
    Deno.env.delete("SUPABASE_URL");
    Deno.env.delete("SUPABASE_SERVICE_ROLE_KEY");
    Deno.env.delete("RATE_LIMIT_SALT");
  }
});
