import { emptyFields, type ParseSource, type ProductFields } from "./types.ts";
import { browserUserAgent } from "./normalizeUrl.ts";

export interface OEmbedResponse {
  thumbnail_url?: string;
  author_name?: string;
  author_url?: string;
  title?: string;
  provider_name?: string;
}

export function oembedEndpoint(source: "instagram" | "tiktok", url: string): string | null {
  if (source === "tiktok") {
    return `https://www.tiktok.com/oembed?url=${encodeURIComponent(url)}`;
  }
  const token = Deno.env.get("INSTAGRAM_OEMBED_TOKEN");
  if (!token) return null;
  return `https://graph.facebook.com/v20.0/instagram_oembed?url=${encodeURIComponent(url)}` +
    `&omitscript=true&access_token=${encodeURIComponent(token)}`;
}

export function mapOEmbed(payload: OEmbedResponse): ProductFields {
  const thumbnail = payload.thumbnail_url?.trim();
  const author = payload.author_name?.trim();
  return {
    ...emptyFields,
    imageURL: thumbnail && thumbnail.length > 0 ? thumbnail : null,
    author: author && author.length > 0 ? author : null,
  };
}

export async function fetchOEmbed(
  source: Extract<ParseSource, "instagram" | "tiktok">,
  url: string,
  fetchImpl: typeof fetch = fetch,
): Promise<ProductFields> {
  const endpoint = oembedEndpoint(source, url);
  if (!endpoint) return { ...emptyFields };
  try {
    const response = await fetchImpl(endpoint, {
      signal: AbortSignal.timeout(8000),
      headers: { accept: "application/json", "user-agent": browserUserAgent },
    });
    if (!response.ok) {
      await response.body?.cancel();
      return { ...emptyFields };
    }
    return mapOEmbed(await response.json() as OEmbedResponse);
  } catch {
    return { ...emptyFields };
  }
}
