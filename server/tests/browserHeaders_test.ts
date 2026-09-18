import { assertEquals } from "@std/assert";
import {
  acceptLanguageFor,
  browserHeaders,
} from "../supabase/functions/_shared/parse/browserHeaders.ts";
import { parseLink } from "../supabase/functions/_shared/parse/index.ts";
import { resolveShortLink } from "../supabase/functions/_shared/parse/normalizeUrl.ts";

interface Recorded {
  url: string;
  headers: Headers;
}

function recordingFetch(calls: Recorded[], response: () => Response): typeof fetch {
  return (input, init) => {
    calls.push({ url: String(input), headers: new Headers(init?.headers) });
    return Promise.resolve(response());
  };
}

Deno.test("the language follows the country the host belongs to", () => {
  assertEquals(acceptLanguageFor("https://www.kleinerladen.de/vase"), "de-DE,de;q=0.9,en;q=0.8");
  assertEquals(acceptLanguageFor("https://www.mytheresa.com/it/it/p/1"), "en-US,en;q=0.9");
  assertEquals(acceptLanguageFor("https://shop.example.co.uk/p/1"), "en-GB,en;q=0.9");
  assertEquals(acceptLanguageFor("https://loja.example.com.br/p/1"), "pt-BR,pt;q=0.9,en;q=0.8");
  assertEquals(acceptLanguageFor("https://example.jp/p/1"), "ja-JP,ja;q=0.9,en;q=0.8");
  assertEquals(acceptLanguageFor("https://example.shop/p/1"), "en-US,en;q=0.9");
  assertEquals(acceptLanguageFor("not a url"), "en-US,en;q=0.9");
});

Deno.test("the header set is the one mobile Safari sends", () => {
  const headers = browserHeaders("https://www.example.fr/p/1");
  assertEquals(headers["user-agent"].includes("iPhone"), true);
  assertEquals(headers["user-agent"].includes("Mobile/15E148 Safari"), true);
  assertEquals(headers["accept"].startsWith("text/html"), true);
  assertEquals(headers["accept-language"], "fr-FR,fr;q=0.9,en;q=0.8");
  assertEquals(headers["upgrade-insecure-requests"], "1");
  assertEquals(headers["sec-fetch-dest"], "document");
  assertEquals(headers["sec-fetch-mode"], "navigate");
  assertEquals(headers["sec-fetch-site"], "none");
  assertEquals(headers["sec-fetch-user"], "?1");
});

Deno.test("fetching a page carries those headers", async () => {
  const calls: Recorded[] = [];
  const fetchImpl = recordingFetch(
    calls,
    () =>
      new Response("<html><head><title>Vase</title></head></html>", {
        headers: { "content-type": "text/html" },
      }),
  );
  await parseLink("https://kleinerladen.de/vasen/nord", fetchImpl);
  assertEquals(calls.length, 1);
  assertEquals(calls[0].headers.get("accept-language"), "de-DE,de;q=0.9,en;q=0.8");
  assertEquals(calls[0].headers.get("sec-fetch-mode"), "navigate");
  assertEquals(calls[0].headers.get("user-agent")?.includes("iPhone"), true);
});

Deno.test("following a short link carries them too", async () => {
  const calls: Recorded[] = [];
  const fetchImpl = recordingFetch(
    calls,
    () =>
      new Response(null, {
        status: 301,
        headers: { location: "https://www.amazon.co.uk/dp/B000P4D5HG" },
      }),
  );
  const resolved = await resolveShortLink("https://amzn.to/3abcdef", fetchImpl);
  assertEquals(resolved, "https://www.amazon.co.uk/dp/B000P4D5HG");
  assertEquals(calls[0].headers.get("user-agent")?.includes("iPhone"), true);
  assertEquals(calls[0].headers.get("accept-language"), "en-US,en;q=0.9");
});
