import { assertEquals } from "@std/assert";
import {
  detectCurrency,
  normalizeCurrencyCode,
  parseAmount,
  parsePrice,
} from "../supabase/functions/_shared/parse/price.ts";

Deno.test("parses the price shapes named in the API contract", () => {
  assertEquals(parsePrice("$1,234.56"), { amount: 1234.56, currency: "USD" });
  assertEquals(parsePrice("1.234,56 EUR"), { amount: 1234.56, currency: "EUR" });
  assertEquals(parsePrice("£12"), { amount: 12, currency: "GBP" });
});

Deno.test("parses amounts with mixed separators", () => {
  assertEquals(parseAmount("24.90"), 24.9);
  assertEquals(parseAmount("24,90"), 24.9);
  assertEquals(parseAmount("1,234"), 1234);
  assertEquals(parseAmount("1.234"), 1234);
  assertEquals(parseAmount("1 299,00"), 1299);
  assertEquals(parseAmount("1'299.00"), 1299);
  assertEquals(parseAmount("Price $69.99"), 69.99);
  assertEquals(parseAmount("138"), 138);
});

Deno.test("rejects amounts that are not prices", () => {
  assertEquals(parseAmount("free"), null);
  assertEquals(parseAmount(""), null);
  assertEquals(parseAmount("0"), null);
  assertEquals(parseAmount("99999999999"), null);
  assertEquals(parsePrice(null), null);
  assertEquals(parsePrice(undefined), null);
});

Deno.test("detects currency from symbol or code", () => {
  assertEquals(detectCurrency("$24.90"), "USD");
  assertEquals(detectCurrency("24,90 €"), "EUR");
  assertEquals(detectCurrency("£42.50"), "GBP");
  assertEquals(detectCurrency("CHF 88.00"), "CHF");
  assertEquals(detectCurrency("CA$19.99"), "CAD");
  assertEquals(detectCurrency("1.299,00 EUR"), "EUR");
  assertEquals(detectCurrency("129,00 zł"), "PLN");
  assertEquals(detectCurrency("19.99"), null);
});

Deno.test("a currency code glued to the amount is still detected", () => {
  assertEquals(parsePrice("EUR23.89"), { amount: 23.89, currency: "EUR" });
  assertEquals(parsePrice("23.89EUR"), { amount: 23.89, currency: "EUR" });
  assertEquals(detectCurrency("USB C Cable"), null);
  assertEquals(detectCurrency("NOWUSD"), null);
});

Deno.test("falls back to the currency the page declared", () => {
  assertEquals(parsePrice("24.90", "SEK"), { amount: 24.9, currency: "SEK" });
  assertEquals(parsePrice("$24.90", "SEK"), { amount: 24.9, currency: "USD" });
  assertEquals(normalizeCurrencyCode("usd"), "USD");
  assertEquals(normalizeCurrencyCode("€"), "EUR");
  assertEquals(normalizeCurrencyCode(null), null);
  assertEquals(normalizeCurrencyCode("dollars"), null);
});
