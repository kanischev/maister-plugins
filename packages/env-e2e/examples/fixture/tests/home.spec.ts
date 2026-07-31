import { expect, test } from "@playwright/test";

test("web service serves the welcome page over internal DNS", async ({
  page,
}) => {
  await page.goto("/");
  await expect(page.locator("h1")).toContainText("Welcome to nginx");
});
