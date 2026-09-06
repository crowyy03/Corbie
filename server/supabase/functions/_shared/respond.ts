export type ErrorCode =
  | "unauthorized"
  | "invalid_request"
  | "not_found"
  | "expired"
  | "redeemed"
  | "rate_limited"
  | "upstream_failed"
  | "internal";

const statusByCode: Record<ErrorCode, number> = {
  unauthorized: 401,
  invalid_request: 400,
  not_found: 404,
  expired: 410,
  redeemed: 410,
  rate_limited: 429,
  upstream_failed: 502,
  internal: 500,
};

export class ApiError extends Error {
  readonly code: ErrorCode;
  readonly status: number;

  constructor(code: ErrorCode, message: string, status?: number) {
    super(message);
    this.name = "ApiError";
    this.code = code;
    this.status = status ?? statusByCode[code];
  }
}

const baseHeaders: Record<string, string> = {
  "cache-control": "no-store",
  "x-content-type-options": "nosniff",
};

export function json(body: unknown, status = 200, headers: Record<string, string> = {}): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...baseHeaders, ...headers, "content-type": "application/json; charset=utf-8" },
  });
}

export function empty(status: number, headers: Record<string, string> = {}): Response {
  return new Response(null, { status, headers: { ...baseHeaders, ...headers } });
}

export function failure(code: ErrorCode, message: string, status?: number): Response {
  return json({ error: code, message }, status ?? statusByCode[code]);
}

export function errorResponse(cause: unknown): Response {
  if (cause instanceof ApiError) return failure(cause.code, cause.message, cause.status);
  console.error("unhandled", cause);
  return failure("internal", "Something went wrong on our side");
}

export function serve(handler: (req: Request) => Promise<Response>): void {
  Deno.serve(async (req) => {
    try {
      return await handler(req);
    } catch (cause) {
      return errorResponse(cause);
    }
  });
}

export function requireMethod(req: Request, method: string): void {
  if (req.method !== method) {
    throw new ApiError("invalid_request", `Use ${method} for this endpoint`, 405);
  }
}

export async function readJson<T>(req: Request): Promise<T> {
  const type = req.headers.get("content-type") ?? "";
  if (!type.toLowerCase().includes("application/json")) {
    throw new ApiError("invalid_request", "Content-Type must be application/json");
  }
  try {
    return await req.json() as T;
  } catch {
    throw new ApiError("invalid_request", "Body is not valid JSON");
  }
}

export function bearerToken(req: Request): string {
  const header = req.headers.get("authorization") ?? "";
  const match = header.match(/^Bearer\s+(.+)$/i);
  if (!match) throw new ApiError("unauthorized", "Authorization header is missing");
  return match[1].trim();
}

export function pathSegments(req: Request, functionName: string): string[] {
  const parts = new URL(req.url).pathname.split("/").filter((part) => part.length > 0);
  const index = parts.lastIndexOf(functionName);
  const tail = index >= 0 ? parts.slice(index + 1) : parts;
  return tail.map((part) => decodeURIComponent(part));
}

const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export function isUuid(value: unknown): value is string {
  return typeof value === "string" && uuidPattern.test(value);
}

export function requireUuid(value: unknown, field: string): string {
  if (!isUuid(value)) throw new ApiError("invalid_request", `${field} must be a UUID`);
  return value.toLowerCase();
}

export function requiredEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value || value.length === 0) {
    throw new ApiError("internal", `Server is missing ${name}`);
  }
  return value;
}
