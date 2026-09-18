export const browserUserAgent =
  "Mozilla/5.0 (iPhone; CPU iPhone OS 18_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.5 Mobile/15E148 Safari/604.1";

export const browserAccept = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8";

const fallbackLanguage = "en-US";

const languageByRegion: Record<string, string> = {
  ae: "ar-AE",
  ar: "es-AR",
  at: "de-AT",
  au: "en-AU",
  be: "nl-BE",
  bg: "bg-BG",
  br: "pt-BR",
  ca: "en-CA",
  ch: "de-CH",
  cl: "es-CL",
  cn: "zh-CN",
  co: "es-CO",
  cz: "cs-CZ",
  de: "de-DE",
  dk: "da-DK",
  ee: "et-EE",
  es: "es-ES",
  fi: "fi-FI",
  fr: "fr-FR",
  gr: "el-GR",
  hk: "zh-HK",
  hr: "hr-HR",
  hu: "hu-HU",
  id: "id-ID",
  ie: "en-IE",
  il: "he-IL",
  in: "en-IN",
  it: "it-IT",
  jp: "ja-JP",
  kr: "ko-KR",
  kz: "ru-KZ",
  lt: "lt-LT",
  lv: "lv-LV",
  mx: "es-MX",
  my: "ms-MY",
  nl: "nl-NL",
  no: "nb-NO",
  nz: "en-NZ",
  pe: "es-PE",
  ph: "en-PH",
  pl: "pl-PL",
  pt: "pt-PT",
  ro: "ro-RO",
  rs: "sr-RS",
  ru: "ru-RU",
  sa: "ar-SA",
  se: "sv-SE",
  sg: "en-SG",
  si: "sl-SI",
  sk: "sk-SK",
  th: "th-TH",
  tr: "tr-TR",
  tw: "zh-TW",
  ua: "uk-UA",
  uk: "en-GB",
  us: "en-US",
  uz: "uz-UZ",
  vn: "vi-VN",
  za: "en-ZA",
};

function regionOf(host: string): string | null {
  const labels = host.toLowerCase().split(".").filter((label) => label.length > 0);
  const last = labels.at(-1);
  if (!last || last.length !== 2) return null;
  return last;
}

export function acceptLanguageFor(target: string | URL): string {
  let host: string;
  try {
    host = (target instanceof URL ? target : new URL(target)).hostname;
  } catch {
    return `${fallbackLanguage},en;q=0.9`;
  }
  const region = regionOf(host);
  const tag = (region && languageByRegion[region]) ?? fallbackLanguage;
  const language = tag.split("-")[0];
  if (language === "en") return `${tag},en;q=0.9`;
  return `${tag},${language};q=0.9,en;q=0.8`;
}

export function browserHeaders(target: string | URL): Record<string, string> {
  return {
    "user-agent": browserUserAgent,
    "accept": browserAccept,
    "accept-language": acceptLanguageFor(target),
    "upgrade-insecure-requests": "1",
    "sec-fetch-dest": "document",
    "sec-fetch-mode": "navigate",
    "sec-fetch-site": "none",
    "sec-fetch-user": "?1",
  };
}
