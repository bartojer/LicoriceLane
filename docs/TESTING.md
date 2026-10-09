# Testing strategy and agent workflow

This records the user's agreed preference: agents will perform most test execution and debugging. Choose tooling for reproducible runs and useful failure evidence, rather than the language preference of a human test author.

## Agreed tools

- Use ExUnit context tests for business rules, persistence, transactions, and write side effects.
- Use Phoenix.LiveViewTest for broad server-side UI coverage. It simulates events through Elixir processes and does not execute browser JavaScript.
- Use the official Playwright Test runner (`@playwright/test`) in TypeScript for expanded browser E2E coverage, including JavaScript behavior, uploads, navigation, and critical user flows.
- PhoenixTestPlaywright and Wallaby are alternatives, not the selected defaults. Reconsider them if a concrete integration benefit outweighs the extra abstraction; choosing Elixir alone is not a reason to switch.

The Playwright preference is a tooling-fit decision. No comparative speed benchmark or categorical security advantage has been established.

## Current implementation

The repository currently has a targeted browser regression in [inventory_upload.cjs](../test/browser/inventory_upload.cjs), invoked by [InventoryUploadTest](../test/licorice_lane_web/live/inventory_upload_test.exs). ExUnit starts a loopback test server, creates sandboxed fixtures, runs the Playwright library script, and checks database persistence and image serving afterward.

This is real browser coverage, but it is not the full Playwright Test runner. There is currently no project Playwright Test configuration, pinned npm dependency/lockfile for that runner, or configured JSON reports and failure traces. The existing browser case is optional and skips when `UPLOAD_BROWSER_NODE` is absent. Keep this regression working during any runner migration.

The [README](../README.md#running-tests-from-windows-through-wsl) documents the Elixir/WSL setup and, under production configuration, the current browser runtime variables. Existing commands are:

```text
mix test
mix test test/licorice_lane_web/live/inventory_upload_test.exs
mix test test/licorice_lane_web/live/inventory_upload_test.exs --only browser
```

The last command requires the browser runtime variables described in README. Rebuild assets with `mix assets.build` before browser validation when source assets or their dependencies have changed. A skipped browser case is not proof that browser behavior passed.

## Requirements when establishing the broader E2E runner

- Provide documented commands for running the suite and a single failing test headlessly, without interactive setup. Document server startup, database setup, fixture lifecycle, and cleanup.
- Pin dependency versions through the package lockfile and use Playwright-managed browser versions for repeatable CI runs. Document any local browser override.
- Keep database fixtures and runtime upload files isolated between tests and workers. Preserve rollback/cleanup when replacing the current ExUnit wrapper; parallelize only after isolation is established.
- Configure machine-readable JSON results alongside concise terminal output. Retain failure traces and screenshots, and capture relevant browser console errors and server logs. Document where artifacts are saved so agents can inspect them.
- Make browser coverage required in its designated CI job. Missing prerequisites must fail that job explicitly; do not silently treat optional local coverage as a required E2E pass.
- Keep fixture data synthetic and test credentials separate from production. Exclude authentication state and generated artifacts from Git, and limit sensitive data in logs and traces.

These describe the agreed target setup, not features already configured in the current harness.

## Agent debugging workflow

1. Run the focused test and inspect its expected result, failure output, and available artifacts before changing code.
2. Reproduce the failure with the documented command and determine whether the defect is in the application, test, environment, or fixture isolation.
3. Preserve the tested business behavior. Do not weaken assertions, add arbitrary sleeps, increase retries, or skip a test just to produce a green result. Change an expectation only when intended behavior changed or the test is demonstrably incorrect, and explain the evidence.
4. Verify the correction with the relevant tests. Broaden testing when the change affects shared behavior or leaves unresolved concerns; avoid repeated broad runs without a reason.
5. Report what actually ran, the results, any retries/skips, and missing prerequisites. Use failure artifacts to explain unresolved issues. Keep application defects visible rather than allowing automatic test-healing to hide them.
