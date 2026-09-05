export const inviteAlphabet = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";
export const inviteCodeLength = 6;

const rejectionThreshold = 256 - (256 % inviteAlphabet.length);

export function generateInviteCode(): string {
  let code = "";
  const buffer = new Uint8Array(inviteCodeLength * 2);
  while (code.length < inviteCodeLength) {
    crypto.getRandomValues(buffer);
    for (const byte of buffer) {
      if (byte >= rejectionThreshold) continue;
      code += inviteAlphabet[byte % inviteAlphabet.length];
      if (code.length === inviteCodeLength) break;
    }
  }
  return code;
}

export function normalizeInviteCode(raw: string): string | null {
  const code = raw.trim().toUpperCase();
  if (code.length !== inviteCodeLength) return null;
  for (const character of code) {
    if (!inviteAlphabet.includes(character)) return null;
  }
  return code;
}
