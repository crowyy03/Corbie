import type { HTMLDocument } from "../html.ts";
import { emptyFields, type ProductFields } from "./types.ts";

const siteSeparators = [" - ", " | ", " : ", ". "];
const secondLevelLabels = new Set(["co", "com", "org", "net", "ac", "gov", "edu"]);

interface HostName {
  brand: string;
  topLevel: string;
}

function words(value: string): string[] {
  return value.normalize("NFKD").toLowerCase().replace(/[&'’]/g, "").split(/[^a-z0-9]+/)
    .filter((word) => word.length > 0);
}

export function hostName(host: string): HostName {
  const labels = host.toLowerCase().split(".").filter((label) => label.length > 0);
  const topLevel = labels.at(-1) ?? "";
  const underCountry = labels.length >= 3 && topLevel.length === 2 &&
    secondLevelLabels.has(labels.at(-2) ?? "");
  const brand = (underCountry ? labels.at(-3) : labels.at(-2)) ?? labels[0] ?? "";
  return { brand, topLevel };
}

function namesTheSite(segment: string, siteNames: string[], topLevel: string): boolean {
  const parts = words(segment);
  if (parts.length === 0) return false;
  const last = parts[parts.length - 1];
  const withoutRegion = parts.length > 1 && (last.length === 2 || last === topLevel)
    ? parts.slice(0, -1).join("")
    : null;
  const whole = parts.join("");
  return siteNames.some((name) => name === whole || name === withoutRegion);
}

export function stripSiteName(title: string, siteName: string | null, host: string): string {
  const { brand, topLevel } = hostName(host);
  const siteNames = [siteName, brand]
    .filter((name): name is string => name !== null)
    .map((name) => words(name).join(""))
    .filter((name) => name.length > 0);

  const cuts = siteSeparators
    .map((separator) => ({ separator, at: title.lastIndexOf(separator) }))
    .filter(({ at }) => at > 0)
    .sort((left, right) => right.at - left.at);
  for (const { separator, at } of cuts) {
    if (namesTheSite(title.slice(at + separator.length), siteNames, topLevel)) {
      return title.slice(0, at).trim();
    }
  }
  return title;
}

export function extractTitleTag(doc: HTMLDocument): ProductFields {
  const title = doc.querySelector("title")?.textContent?.trim() ?? "";
  return { ...emptyFields, title: title.length > 0 ? title : null };
}
