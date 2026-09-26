import { assertEquals, assertMatch } from "@std/assert";
import { parseLogLine } from "../supabase/functions/_shared/parse/log.ts";

type Handler = (req: Request) => Promise<Response>;

const served: { handler?: Handler } = {};
const realServe = Object.getOwnPropertyDescriptor(Deno, "serve")!;
Object.defineProperty(Deno, "serve", {
  configurable: true,
  value: (handler: Handler) => {
    served.handler = handler;
  },
});
await import("../supabase/functions/parse/index.ts");
Object.defineProperty(Deno, "serve", realServe);

Deno.test("a fetched parse logs one line of host, cache, upstream, page, readers and time", () => {
  assertEquals(
    parseLogLine({
      host: "walmart.com",
      cache: "miss",
      trace: { upstream: 200, page: "product", titleFrom: "og", priceFrom: "microdata" },
      ms: 1370.4,
    }),
    "parse host=walmart.com cache=miss upstream=200 page=product title=og price=microdata ms=1370",
  );
  assertEquals(
    parseLogLine({
      host: "etsy.com",
      cache: "miss",
      trace: { upstream: 403, page: "unread", titleFrom: "none", priceFrom: "none" },
      ms: 191.6,
    }),
    "parse host=etsy.com cache=miss upstream=403 page=unread title=none price=none ms=192",
  );
});

Deno.test("a cache hit keeps the same keys with nothing to report upstream", () => {
  assertEquals(
    parseLogLine({ host: "ikea.com", cache: "hit", trace: null, ms: 35 }),
    "parse host=ikea.com cache=hit upstream=- page=- title=- price=- ms=35",
  );
});

const databaseHost = "corbie-db.test";
const walmartLink = "https://www.walmart.com/ip/Apple-AirPods-4/11381374703";

function jsonResponse(body: unknown): Response {
  return new Response(JSON.stringify(body), { headers: { "content-type": "application/json" } });
}

function callParse(url: string): Promise<Response> {
  if (!served.handler) throw new Error("parse/index.ts did not register a handler");
  return served.handler(
    new Request("https://corbie.test/functions/v1/parse", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ url }),
    }),
  );
}

Deno.test("the handler logs exactly one line for a miss and one for the hit that follows", async () => {
  const walmart = await Deno.readTextFile(new URL("./fixtures/walmart.html", import.meta.url));
  const cacheRows: { payload: unknown; fetched_at: string }[] = [];
  const shopRequests: string[] = [];
  const stubbed: typeof fetch = async (input, init) => {
    const request = new Request(input, init);
    const url = new URL(request.url);
    if (url.hostname !== databaseHost) {
      shopRequests.push(url.toString());
      return new Response(walmart, { headers: { "content-type": "text/html" } });
    }
    if (url.pathname === "/rest/v1/rpc/rate_limit_take") return jsonResponse(true);
    if (url.pathname === "/rest/v1/parse_cache" && request.method === "GET") {
      return jsonResponse(cacheRows);
    }
    if (url.pathname === "/rest/v1/parse_cache" && request.method === "POST") {
      const { payload } = await request.json();
      cacheRows.push({ payload, fetched_at: new Date().toISOString() });
      return new Response(null, { status: 201 });
    }
    return new Response("no route", { status: 404 });
  };

  const info: string[] = [];
  const errors: unknown[][] = [];
  const realFetch = globalThis.fetch;
  const realInfo = console.info;
  const realError = console.error;
  const realResolveDns = Object.getOwnPropertyDescriptor(Deno, "resolveDns")!;
  globalThis.fetch = stubbed;
  console.info = (line: string) => info.push(line);
  console.error = (...args: unknown[]) => errors.push(args);
  Object.defineProperty(Deno, "resolveDns", {
    configurable: true,
    value: (_host: string, kind: string) => Promise.resolve(kind === "A" ? ["93.184.216.34"] : []),
  });
  Deno.env.set("SUPABASE_URL", `https://${databaseHost}`);
  Deno.env.set("SUPABASE_SERVICE_ROLE_KEY", "test-service-role-key");
  try {
    const miss = await callParse(walmartLink);
    assertEquals((await miss.json()).price, 99);
    assertEquals(info.length, 1);
    assertMatch(
      info[0],
      /^parse host=walmart\.com cache=miss upstream=200 page=product title=og price=microdata ms=\d+$/,
    );
    assertEquals(cacheRows.length, 1);

    const hit = await callParse(walmartLink);
    assertEquals((await hit.json()).price, 99);
    assertEquals(info.length, 2);
    assertMatch(
      info[1],
      /^parse host=walmart\.com cache=hit upstream=- page=- title=- price=- ms=\d+$/,
    );
    assertEquals(shopRequests.length, 1);
    assertEquals(errors, []);
  } finally {
    globalThis.fetch = realFetch;
    console.info = realInfo;
    console.error = realError;
    Object.defineProperty(Deno, "resolveDns", realResolveDns);
    Deno.env.delete("SUPABASE_URL");
    Deno.env.delete("SUPABASE_SERVICE_ROLE_KEY");
  }
});
