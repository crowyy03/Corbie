import type { Adapter } from "./adapter.ts";
import { amazonAdapter } from "./amazon.ts";
import { etsyAdapter } from "./etsy.ts";
import { ikeaAdapter } from "./ikea.ts";
import { nordstromAdapter } from "./nordstrom.ts";
import { sephoraAdapter } from "./sephora.ts";
import { targetAdapter } from "./target.ts";
import { zaraAdapter } from "./zara.ts";

export type { Adapter };

export const adapters: Adapter[] = [
  amazonAdapter,
  targetAdapter,
  etsyAdapter,
  sephoraAdapter,
  nordstromAdapter,
  zaraAdapter,
  ikeaAdapter,
];

export function adapterForHost(host: string): Adapter | null {
  return adapters.find((adapter) => adapter.matches(host)) ?? null;
}
