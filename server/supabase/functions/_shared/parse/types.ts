export type ParseSource =
  | "amazon"
  | "target"
  | "etsy"
  | "sephora"
  | "nordstrom"
  | "zara"
  | "ikea"
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

export function mergeFields(primary: ProductFields, fallback: ProductFields): ProductFields {
  const currency = primary.price !== null
    ? primary.currency ?? fallback.currency
    : fallback.currency ?? primary.currency;
  return {
    title: primary.title ?? fallback.title,
    price: primary.price ?? fallback.price,
    currency: primary.price === null && fallback.price === null ? null : currency,
    imageURL: primary.imageURL ?? fallback.imageURL,
    author: primary.author ?? fallback.author,
  };
}
