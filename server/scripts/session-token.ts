import { issueSessionToken, verifySessionToken } from "../supabase/functions/_shared/sessionToken.ts";

const subject = Deno.args[0] ?? "corbie-smoke-test";
const session = await issueSessionToken(subject);
await verifySessionToken(session.token);
console.log(session.token);
