import { requireUser } from "../_shared/auth.ts";
import { buckets, enforceRateLimit } from "../_shared/rateLimit.ts";
import {
  ApiError,
  json,
  pathSegments,
  requireMethod,
  requireUuid,
  serve,
} from "../_shared/respond.ts";
import { serviceClient } from "../_shared/supabase.ts";

interface EntitlementRow {
  space_id: string;
  status: string;
  product_id: string | null;
  expires_at: string | null;
  updated_at: string;
}

async function handle(req: Request): Promise<Response> {
  requireMethod(req, "GET");
  await enforceRateLimit(req, "entitlement", buckets.entitlement);
  await requireUser(req);

  const segments = pathSegments(req, "entitlement");
  const spaceId = requireUuid(segments[0], "spaceId");

  const { data, error } = await serviceClient()
    .from("entitlements")
    .select("space_id, status, product_id, expires_at, updated_at")
    .eq("space_id", spaceId)
    .maybeSingle<EntitlementRow>();
  if (error) {
    console.error("entitlement lookup failed", error);
    throw new ApiError("internal", "Could not read the subscription");
  }

  if (!data) {
    return json({
      spaceId,
      status: "none",
      productId: null,
      expiresAt: null,
      updatedAt: null,
    });
  }

  return json({
    spaceId: data.space_id,
    status: data.status,
    productId: data.product_id,
    expiresAt: data.expires_at,
    updatedAt: data.updated_at,
  });
}

serve(handle);
