import { assert, assertEquals } from "@std/assert";
import {
  generateInviteCode,
  inviteAlphabet,
  inviteCodeLength,
  normalizeInviteCode,
} from "../supabase/functions/_shared/inviteCode.ts";

Deno.test("invite alphabet has no ambiguous characters", () => {
  assertEquals(inviteAlphabet, "ABCDEFGHJKMNPQRSTUVWXYZ23456789");
  for (const character of "IL01O") {
    assert(!inviteAlphabet.includes(character), `${character} must not be in the alphabet`);
  }
  assertEquals(new Set(inviteAlphabet).size, inviteAlphabet.length);
});

Deno.test("generated codes stay inside the alphabet and length", () => {
  const seen = new Set<string>();
  for (let i = 0; i < 2000; i++) {
    const code = generateInviteCode();
    assertEquals(code.length, inviteCodeLength);
    for (const character of code) assert(inviteAlphabet.includes(character), code);
    seen.add(code);
  }
  assert(seen.size > 1900, `expected varied codes, got ${seen.size} unique`);
});

Deno.test("generated codes cover the whole alphabet", () => {
  const used = new Set<string>();
  for (let i = 0; i < 5000; i++) {
    for (const character of generateInviteCode()) used.add(character);
  }
  assertEquals(used.size, inviteAlphabet.length);
});

Deno.test("normalize accepts lowercase and rejects bad codes", () => {
  assertEquals(normalizeInviteCode(" k7m2qx "), "K7M2QX");
  assertEquals(normalizeInviteCode("K7M2QX"), "K7M2QX");
  assertEquals(normalizeInviteCode("K7M2Q"), null);
  assertEquals(normalizeInviteCode("K7M2QXX"), null);
  assertEquals(normalizeInviteCode("K7M2Q0"), null);
  assertEquals(normalizeInviteCode("K7M2QI"), null);
  assertEquals(normalizeInviteCode("K7M2Q-"), null);
});
