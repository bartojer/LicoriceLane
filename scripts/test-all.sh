#!/usr/bin/env bash
# Run from WSL/Linux with the README's Mix and browser runtime configured.
set -euo pipefail
cd "$(dirname "$0")/.."
: "${UPLOAD_BROWSER_NODE:?Set UPLOAD_BROWSER_NODE; required browser checks must not skip}"
"$UPLOAD_BROWSER_NODE" -e '
  const fs = require("node:fs");
  const modulePath = process.env.UPLOAD_PLAYWRIGHT_MODULE || "playwright";
  const {chromium} = require(modulePath);
  require(modulePath + "/test");
  const executable = process.env.UPLOAD_BROWSER_EXECUTABLE || chromium.executablePath();
  if (!fs.existsSync(executable)) throw new Error("Browser missing: " + executable);
'
mkdir -p _build/test-suite-results
seed="${TEST_SEED:-0}"
mix test test/licorice_lane_web/live/inventory_upload_test.exs --only browser --seed "$seed" 2>&1 | tee _build/test-suite-results/upload.log
mix test test/licorice_lane_web/live/admin_inventory_delete_test.exs --only browser --seed "$seed" 2>&1 | tee _build/test-suite-results/delete.log
mix test --exclude browser --seed "$seed" 2>&1 | tee _build/test-suite-results/exunit.log
