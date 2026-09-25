import { sha256Hex } from "./hash.ts";
import { ApiError, bearerToken } from "./respond.ts";

export async function requireServiceRole(req: Request): Promise<void> {
  const expected = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (expected.length === 0) {
    throw new ApiError("internal", "Server is missing SUPABASE_SERVICE_ROLE_KEY");
  }
  const presented = bearerToken(req);
  if (await sha256Hex(presented) !== await sha256Hex(expected)) {
    throw new ApiError("unauthorized", "This endpoint takes the service role key");
  }
}
