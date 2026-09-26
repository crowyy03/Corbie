import { assertEquals } from "@std/assert";
import {
  acceptAmount,
  detectCurrency,
  hasNoMinorUnit,
  normalizeCurrencyCode,
  parseAmount,
  parsePrice,
  showsMinorUnit,
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
  assertEquals(detectCurrency("299 kr"), null);
  assertEquals(detectCurrency("299 SEK"), "SEK");
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

Deno.test("a price text without a decimal part reads as whole units", () => {
  assertEquals(parsePrice("EUR1403"), { amount: 1403, currency: "EUR" });
});

Deno.test("amounts are rounded to two decimals and must be positive", () => {
  assertEquals(acceptAmount(14.03), 14.03);
  assertEquals(acceptAmount(16.807), 16.81);
  assertEquals(acceptAmount(0), null);
  assertEquals(acceptAmount(Number.NaN), null);
});

Deno.test("a price text shows its minor unit only with two digits after the last separator", () => {
  assertEquals(showsMinorUnit("$24.90"), true);
  assertEquals(showsMinorUnit("24,90 €"), true);
  assertEquals(showsMinorUnit("1.234,56 EUR"), true);
  assertEquals(showsMinorUnit("EUR1403"), false);
  assertEquals(showsMinorUnit("$1,234"), false);
  assertEquals(showsMinorUnit("¥1,234"), false);
});

Deno.test("yen and won are the supported currencies without a minor unit", () => {
  assertEquals(hasNoMinorUnit("JPY"), true);
  assertEquals(hasNoMinorUnit("KRW"), true);
  assertEquals(hasNoMinorUnit("EUR"), false);
  assertEquals(hasNoMinorUnit("HUF"), false);
  assertEquals(hasNoMinorUnit(null), false);
});
