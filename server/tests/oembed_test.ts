import { assertEquals } from "@std/assert";
import {
  fetchOEmbed,
  mapOEmbed,
  oembedEndpoint,
} from "../supabase/functions/_shared/parse/oembed.ts";
import { parseLink } from "../supabase/functions/_shared/parse/index.ts";

Deno.test("maps an oembed payload to image and author only", () => {
  assertEquals(
    mapOEmbed({
      thumbnail_url: "https://p16.tiktokcdn.com/cover.jpeg",
      author_name: "cafe.nordic",
      title: "look at this cup",
      provider_name: "TikTok",
    }),
    {
      title: null,
      price: null,
      currency: null,
      imageURL: "https://p16.tiktokcdn.com/cover.jpeg",
      author: "cafe.nordic",
    },
  );
});

Deno.test("treats blank oembed fields as missing", () => {
  assertEquals(mapOEmbed({ thumbnail_url: "  ", author_name: "" }).imageURL, null);
  assertEquals(mapOEmbed({}).author, null);
});

Deno.test("tiktok endpoint needs no token, instagram does", () => {
  const url = "https://www.tiktok.com/@cafe.nordic/video/7300";
  assertEquals(
    oembedEndpoint("tiktok", url),
    `https://www.tiktok.com/oembed?url=${encodeURIComponent(url)}`,
  );
  Deno.env.delete("INSTAGRAM_OEMBED_TOKEN");
  assertEquals(oembedEndpoint("instagram", "https://www.instagram.com/p/ABC/"), null);
});

Deno.test("tiktok links resolve through oembed with no title or price", async () => {
  const calls: string[] = [];
  const fetchImpl: typeof fetch = (input) => {
    calls.push(input instanceof Request ? input.url : String(input));
    return Promise.resolve(
      new Response(
        JSON.stringify({
          thumbnail_url: "https://p16.tiktokcdn.com/cover.jpeg",
          author_name: "cafe.nordic",
          title: "look at this cup",
        }),
        { headers: { "content-type": "application/json" } },
      ),
    );
  };

  const result = await parseLink(
    "https://www.tiktok.com/@cafe.nordic/video/7300?utm_source=share",
    fetchImpl,
  );
  assertEquals(result, {
    canonicalURL: "https://www.tiktok.com/@cafe.nordic/video/7300",
    source: "tiktok",
    title: null,
    price: null,
    currency: null,
    imageURL: "https://p16.tiktokcdn.com/cover.jpeg",
    author: "cafe.nordic",
  });
  assertEquals(calls.length, 1);
});

Deno.test("instagram without a token still returns the canonical url", async () => {
  Deno.env.delete("INSTAGRAM_OEMBED_TOKEN");
  let called = 0;
  const fetchImpl: typeof fetch = () => {
    called += 1;
    return Promise.resolve(new Response("{}"));
  };
  const result = await parseLink("https://www.instagram.com/p/ABC123/?igshid=9", fetchImpl);
  assertEquals(result.canonicalURL, "https://www.instagram.com/p/ABC123");
  assertEquals(result.source, "instagram");
  assertEquals(result.imageURL, null);
  assertEquals(called, 0);
});

Deno.test("a failing oembed upstream degrades to the bare result", async () => {
  const fetchImpl: typeof fetch = () => Promise.resolve(new Response("nope", { status: 500 }));
  const result = await fetchOEmbed("tiktok", "https://www.tiktok.com/@a/video/1", fetchImpl);
  assertEquals(result.imageURL, null);
  assertEquals(result.author, null);
});
