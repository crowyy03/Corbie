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
const { monetizationEnabledFrom } = await import("../supabase/functions/config/index.ts");
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

function assertInternal(read: Parameters<typeof monetizationEnabledFrom>[0]): void {
  const error = assertThrows(() => monetizationEnabledFrom(read), ApiError) as ApiError;
  assertEquals(error.code, "internal");
  assertEquals(error.status, 500);
}

Deno.test("a stored boolean is returned as it is", () => {
  assertEquals(monetizationEnabledFrom({ data: { value: true }, error: null }), true);
  assertEquals(monetizationEnabledFrom({ data: { value: false }, error: null }), false);
});

Deno.test("a missing row means monetization is off", () => {
  assertEquals(monetizationEnabledFrom({ data: null, error: null }), false);
});

Deno.test("a database error is an internal error, never a default false", () => {
  assertInternal({ data: null, error: { message: "connection refused" } });
  assertInternal({ data: { value: false }, error: { message: "partial read" } });
  assertInternal({ data: { value: true }, error: { message: "partial read" } });
});

Deno.test("a stored value that is not a JSON boolean is an internal error", () => {
  for (const value of ["true", "false", 1, 0, null, {}, [], [true], { enabled: true }]) {
    assertInternal({ data: { value }, error: null });
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
  try {
    const response = await callConfig();
    const body = await response.json();
    assertEquals(response.status, 500);
    assertEquals(body.error, "internal");
    assertEquals("monetizationEnabled" in body, false);
  } finally {
    Deno.env.delete("SUPABASE_URL");
    Deno.env.delete("SUPABASE_SERVICE_ROLE_KEY");
  }
});
