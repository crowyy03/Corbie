export interface Price {
  amount: number;
  currency: string | null;
}

const currencyBySymbol: Record<string, string> = {
  "$": "USD",
  "US$": "USD",
  "€": "EUR",
  "£": "GBP",
  "¥": "JPY",
  "₹": "INR",
  "₽": "RUB",
  "₩": "KRW",
  "₺": "TRY",
  "₴": "UAH",
  "₪": "ILS",
  "zł": "PLN",
  "Kč": "CZK",
  "R$": "BRL",
  "C$": "CAD",
  "CA$": "CAD",
  "A$": "AUD",
  "AU$": "AUD",
  "NZ$": "NZD",
  "HK$": "HKD",
  "S$": "SGD",
  "MX$": "MXN",
  "CHF": "CHF",
  "SEK": "SEK",
  "NOK": "NOK",
  "DKK": "DKK",
};

const knownCodes = new Set([
  "AED",
  "AUD",
  "BRL",
  "CAD",
  "CHF",
  "CNY",
  "CZK",
  "DKK",
  "EUR",
  "GBP",
  "HKD",
  "HUF",
  "ILS",
  "INR",
  "JPY",
  "KRW",
  "MXN",
  "NOK",
  "NZD",
  "PLN",
  "RON",
  "RUB",
  "SEK",
  "SGD",
  "TRY",
  "UAH",
  "USD",
  "ZAR",
]);

const prefixSymbols = ["CA$", "AU$", "NZ$", "HK$", "MX$", "US$", "R$", "C$", "A$", "S$"];

export function detectCurrency(raw: string): string | null {
  const text = raw.replace(/ /g, " ").trim();

  for (const match of text.matchAll(/(?<![A-Za-z])([A-Z]{3})(?![A-Za-z])/g)) {
    if (knownCodes.has(match[1])) return match[1];
  }

  for (const symbol of prefixSymbols) {
    if (text.includes(symbol)) return currencyBySymbol[symbol];
  }
  for (const [symbol, currency] of Object.entries(currencyBySymbol)) {
    if (symbol.length === 3 && /^[A-Z]+$/.test(symbol)) continue;
    if (text.includes(symbol)) return currency;
  }
  return null;
}

export function parseAmount(raw: string): number | null {
  const text = raw.replace(/ /g, " ");
  const match = text.match(/\d[\d.,\s ']*\d|\d/);
  if (!match) return null;

  let digits = match[0].replace(/[\s ']/g, "");
  const lastDot = digits.lastIndexOf(".");
  const lastComma = digits.lastIndexOf(",");

  if (lastDot >= 0 && lastComma >= 0) {
    const decimalSeparator = lastDot > lastComma ? "." : ",";
    const groupSeparator = decimalSeparator === "." ? "," : ".";
    digits = digits.split(groupSeparator).join("");
    digits = digits.replace(decimalSeparator, ".");
  } else if (lastDot >= 0 || lastComma >= 0) {
    const separator = lastDot >= 0 ? "." : ",";
    const index = lastDot >= 0 ? lastDot : lastComma;
    const tail = digits.length - index - 1;
    const occurrences = digits.split(separator).length - 1;
    if (occurrences > 1 || tail === 3) {
      digits = digits.split(separator).join("");
    } else {
      digits = digits.split(separator).join(".");
    }
  }

  const amount = Number(digits);
  if (!Number.isFinite(amount) || amount <= 0 || amount > 10_000_000) return null;
  return Math.round(amount * 100) / 100;
}

export function parsePrice(
  raw: string | null | undefined,
  fallbackCurrency?: string | null,
): Price | null {
  if (!raw) return null;
  const amount = parseAmount(raw);
  if (amount === null) return null;
  const currency = detectCurrency(raw) ?? normalizeCurrencyCode(fallbackCurrency);
  return { amount, currency };
}

export function normalizeCurrencyCode(raw: string | null | undefined): string | null {
  if (!raw) return null;
  const code = raw.trim().toUpperCase();
  if (/^[A-Z]{3}$/.test(code)) return code;
  return detectCurrency(code);
}
