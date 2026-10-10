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

[inventory_delete.cjs](../test/browser/inventory_delete.cjs), invoked by [AdminInventoryDeleteTest](../test/licorice_lane_web/live/admin_inventory_delete_test.exs), adds one focused browser case for Cancel, Escape, and confirmed single/bulk deletion. It uses the same runtime variables and sandboxed server, with database cleanup asserted afterward. When `UPLOAD_BROWSER_SCRIPT` is set for Windows Node, the deletion script is resolved beside that upload script.

This is real browser coverage, but it is not the full Playwright Test runner. There is currently no project Playwright Test configuration, pinned npm dependency/lockfile for that runner, or configured JSON reports and failure traces. Both browser cases are optional and skip when `UPLOAD_BROWSER_NODE` is absent. Keep these regressions working during any runner migration.

The [README](../README.md#running-tests-from-windows-through-wsl) documents the Elixir/WSL setup and, under production configuration, the current browser runtime variables. Existing commands are:

```text
mix test
mix test test/licorice_lane_web/live/inventory_upload_test.exs
mix test test/licorice_lane_web/live/inventory_upload_test.exs --only browser
mix test test/licorice_lane_web/live/admin_inventory_delete_test.exs --only browser
```

Commands with `--only browser` require the browser runtime variables described in README. Rebuild assets with `mix assets.build` before browser validation when source assets or their dependencies have changed. A skipped browser case is not proof that browser behavior passed.

## Regression testing before pushing

Before pushing to the primary branch (`main` in this repository, or `master` where applicable), run the full ExUnit regression suite and both existing browser regressions against the changes being pushed. Configure the README's browser runtime variables and confirm that the upload and inventory-deletion browser cases run and pass. Their optional local tags do not make them optional for validation before pushing. Skipped tests do not count as completed validation.

Run `mix test --seed 0` with the browser runtime configured to include both cases in the full suite. If the full suite was already run against the same code with those cases skipped, run `mix test test/licorice_lane_web/live/inventory_upload_test.exs test/licorice_lane_web/live/admin_inventory_delete_test.exs --only browser --seed 0` with the runtime configured before pushing.

When controlling a Windows browser from WSL, a combined run has reproduced `ERR_CONNECTION_REFUSED` on upload after the deletion case; upload passes in isolation. Both cases start and stop a loopback server on port 4002, so Windows-to-WSL port forwarding is a suspected cause. To validate every case in separate Mix processes, run `mix test --exclude browser --seed 0`, then run each browser file individually with `--only browser --seed 0` and the browser runtime configured. All three commands must pass; excluding browser cases from the first command does not waive either browser check.

The forwarding failure has also occurred across separate Mix processes. A native Linux Node and Playwright-managed Chromium inside WSL avoid that forwarding dependency. With a compatible Linux Node runtime and an installed Playwright package, use the following in the WSL shell alongside the README's Mix settings (replace the module path):

```bash
export UPLOAD_BROWSER_NODE="$(command -v node)"
export UPLOAD_PLAYWRIGHT_MODULE="/absolute/path/to/node_modules/playwright"
export PLAYWRIGHT_BROWSERS_PATH="$PWD/_build/playwright-browsers"
unset UPLOAD_BROWSER_EXECUTABLE UPLOAD_BROWSER_SCRIPT
"$UPLOAD_BROWSER_NODE" "$UPLOAD_PLAYWRIGHT_MODULE/cli.js" install chromium
```

Use a Node version supported by that Playwright package and install any Linux browser libraries its prerequisite check identifies. Keep `PLAYWRIGHT_BROWSERS_PATH` set when running the tests. The default scripts then resolve from the repository and communicate with the test server within WSL. The October 9 realtime validation used a project-local Linux Node 22.19.0 runtime; generated runtime files remain ignored.

If regressions fail or cannot run, resolve the issue or report the blocker before pushing; do not push while required regression validation remains incomplete.

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
