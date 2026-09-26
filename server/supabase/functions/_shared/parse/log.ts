import type { ParseTrace } from "./upstream.ts";

export interface ParseLogEntry {
  host: string;
  cache: "hit" | "miss";
  trace: ParseTrace | null;
  ms: number;
}

export function parseLogLine(entry: ParseLogEntry): string {
  const { trace } = entry;
  return [
    "parse",
    `host=${entry.host}`,
    `cache=${entry.cache}`,
    `upstream=${trace ? trace.upstream : "-"}`,
    `page=${trace ? trace.page : "-"}`,
    `title=${trace ? trace.titleFrom : "-"}`,
    `price=${trace ? trace.priceFrom : "-"}`,
    `ms=${Math.round(entry.ms)}`,
  ].join(" ");
}
