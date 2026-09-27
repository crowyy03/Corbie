import { assertEquals, assertRejects } from "@std/assert";
import { AppStoreServerApiError } from "../supabase/functions/_shared/appStoreServerApi.ts";
import {
  requestAndAwaitTestNotification,
  statusChecks,
} from "../supabase/functions/_shared/testNotification.ts";

type Status = { signedPayload?: string; sendAttempts?: { sendAttemptResult?: string }[] };

function fakeApi(token: string | undefined, answers: (Status | "not yet")[]) {
  const checked: string[] = [];
  return {
    checked,
    api: {
      environment: "Sandbox" as const,
      requestTestNotification: () => Promise.resolve({ testNotificationToken: token }),
      getTestNotificationStatus: (asked: string) => {
        checked.push(asked);
        const answer = answers.shift() ?? "not yet";
        if (answer === "not yet") {
          return Promise.reject(new AppStoreServerApiError(404, null, "GET status answered 404"));
        }
        return Promise.resolve(answer);
      },
    },
  };
}

const verifiedTest = <T>(jws: string): Promise<T> => {
  if (jws !== "signed.test.payload") return Promise.reject(new Error("bad signature"));
  return Promise.resolve({
    notificationType: "TEST",
    data: { environment: "Sandbox", bundleId: "app.corbie" },
  } as T);
};

Deno.test("a test notification that reached us is reported with its verified payload", async () => {
  const { api, checked } = fakeApi("token-1", [
    "not yet",
    { signedPayload: "signed.test.payload", sendAttempts: [{ sendAttemptResult: "SUCCESS" }] },
  ]);
  const report = await requestAndAwaitTestNotification({
    api,
    verify: verifiedTest,
    sleep: () => Promise.resolve(),
  });
  assertEquals(checked, ["token-1", "token-1"]);
  assertEquals(report, {
    environment: "Sandbox",
    testNotificationToken: "token-1",
    sendAttempts: ["SUCCESS"],
    delivered: true,
    signedPayload: { notificationType: "TEST", environment: "Sandbox", bundleId: "app.corbie" },
  });
});

Deno.test("a failed delivery is reported as not delivered with Apple's reason", async () => {
  const { api } = fakeApi("token-2", [
    {
      signedPayload: "signed.test.payload",
      sendAttempts: [{ sendAttemptResult: "UNSUCCESSFUL_HTTP_RESPONSE_CODE" }],
    },
  ]);
  const report = await requestAndAwaitTestNotification({
    api,
    verify: verifiedTest,
    sleep: () => Promise.resolve(),
  });
  assertEquals(report.delivered, false);
  assertEquals(report.sendAttempts, ["UNSUCCESSFUL_HTTP_RESPONSE_CODE"]);
});

Deno.test("a payload whose signature does not verify fails the check", async () => {
  const { api } = fakeApi("token-3", [
    { signedPayload: "forged", sendAttempts: [{ sendAttemptResult: "SUCCESS" }] },
  ]);
  await assertRejects(() =>
    requestAndAwaitTestNotification({ api, verify: verifiedTest, sleep: () => Promise.resolve() })
  );
});

Deno.test("no attempt within the checks is not delivered, and no token is an error", async () => {
  const { api, checked } = fakeApi("token-4", []);
  const report = await requestAndAwaitTestNotification({
    api,
    verify: verifiedTest,
    sleep: () => Promise.resolve(),
  });
  assertEquals(checked.length, statusChecks);
  assertEquals(report.delivered, false);
  assertEquals(report.sendAttempts, []);

  const tokenless = fakeApi(undefined, []);
  await assertRejects(() =>
    requestAndAwaitTestNotification({
      api: tokenless.api,
      verify: verifiedTest,
      sleep: () => Promise.resolve(),
    })
  );
});
