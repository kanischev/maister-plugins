import { expect, test } from "@playwright/test";

// Toggleable red spec: green by default; `E2E_ENV=(FIXTURE_RED=1)` in
// .maister-env-e2e.sh turns it red — the package's rework-loop exerciser.
test("fixture red toggle is off", () => {
  expect(process.env.FIXTURE_RED ?? "").not.toBe("1");
});
