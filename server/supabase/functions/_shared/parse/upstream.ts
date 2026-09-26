import { GuardRefusal, TooManyRedirects, UnresolvedHost } from "./guard.ts";
import type { FieldSource } from "./types.ts";

export type Upstream =
  | number
  | "timeout"
  | "guard"
  | "unresolved"
  | "too-many-redirects"
  | "error"
  | "non-html"
  | "redirect"
  | "skipped";

export type PageVerdict = "product" | "not-product" | "unread";

export interface ParseTrace {
  upstream: Upstream;
  page: PageVerdict;
  titleFrom: FieldSource;
  priceFrom: FieldSource;
}

export function upstreamFailure(cause: unknown): Upstream {
  if (cause instanceof GuardRefusal) return "guard";
  if (cause instanceof UnresolvedHost) return "unresolved";
  if (cause instanceof TooManyRedirects) return "too-many-redirects";
  if (cause instanceof DOMException && cause.name === "TimeoutError") return "timeout";
  return "error";
}
