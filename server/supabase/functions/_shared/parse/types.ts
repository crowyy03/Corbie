export type ParseSource =
  | "amazon"
  | "target"
  | "etsy"
  | "sephora"
  | "nordstrom"
  | "zara"
  | "ikea"
  | "uniqlo"
  | "instagram"
  | "tiktok"
  | "generic";

export interface ParseResult {
  canonicalURL: string;
  source: ParseSource;
  title: string | null;
  price: number | null;
  currency: string | null;
  imageURL: string | null;
  author: string | null;
}

export interface ProductFields {
  title: string | null;
  price: number | null;
  currency: string | null;
  imageURL: string | null;
  author: string | null;
}

export const emptyFields: ProductFields = {
  title: null,
  price: null,
  currency: null,
  imageURL: null,
  author: null,
};

export type FieldSource = "adapter" | "jsonld" | "og" | "microdata" | "title-tag" | "none";

export interface SourcedFields {
  source: Exclude<FieldSource, "none">;
  fields: ProductFields;
}

export interface MergedFields {
  fields: ProductFields;
  titleFrom: FieldSource;
  priceFrom: FieldSource;
}

export function mergeFields(readings: SourcedFields[]): MergedFields {
  const firstWith = (key: keyof ProductFields) =>
    readings.find((reading) => reading.fields[key] !== null);
  const titled = firstWith("title");
  const priced = firstWith("price");
  const currency = priced
    ? priced.fields.currency ??
      readings.find((reading) => reading.fields.price !== null && reading.fields.currency !== null)
        ?.fields.currency ??
      null
    : null;
  return {
    fields: {
      title: titled?.fields.title ?? null,
      price: priced?.fields.price ?? null,
      currency,
      imageURL: firstWith("imageURL")?.fields.imageURL ?? null,
      author: firstWith("author")?.fields.author ?? null,
    },
    titleFrom: titled?.source ?? "none",
    priceFrom: priced?.source ?? "none",
  };
}
