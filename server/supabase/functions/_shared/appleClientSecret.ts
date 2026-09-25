import { appleClientId } from "./appleAuth.ts";
import { importEs256PrivateKey, signEs256Jwt } from "./es256.ts";
import { requiredEnv } from "./respond.ts";

const audience = "https://appleid.apple.com";
const lifetimeSeconds = 15 * 60;

export async function buildAppleClientSecret(now: Date = new Date()): Promise<string> {
  const teamId = requiredEnv("APPLE_TEAM_ID");
  const keyId = requiredEnv("APPLE_KEY_ID");
  const key = await importEs256PrivateKey(requiredEnv("APPLE_PRIVATE_KEY"), "APPLE_PRIVATE_KEY");

  const issuedAt = Math.floor(now.getTime() / 1000);
  return await signEs256Jwt(key, { alg: "ES256", kid: keyId, typ: "JWT" }, {
    iss: teamId,
    iat: issuedAt,
    exp: issuedAt + lifetimeSeconds,
    aud: audience,
    sub: appleClientId(),
  });
}
