// Shared by the ExUnit-launched smoke cases; credentials/fixtures remain sandbox-owned.
const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const path = require('node:path');
const { chromium } = require(process.argv[4] || 'playwright');
const { expect } = require((process.argv[4] || 'playwright') + '/test');

async function openLive(page, pathname) {
  await page.goto('http://localhost:4002' + pathname);
  await page.waitForFunction(() => document.querySelector('[data-phx-main]')?.classList.contains('phx-connected'));
}

async function runSmoke(name, scenario) {
  const started = Date.now();
  const directory = path.resolve(__dirname, '../../_build/browser-results', `${name}-${started}-${process.pid}`);
  const errors = [];
  const consoleErrors = [];
  let browser, context, failure;
  await fs.mkdir(directory, { recursive: true });
  try {
    browser = await chromium.launch({ headless: true, ...(process.argv[5] ? { executablePath: process.argv[5] } : {}) });
    context = await browser.newContext();
    context.on('page', page => {
      page.on('pageerror', error => errors.push(error.message));
      page.on('console', message => { if (message.type() === 'error') consoleErrors.push(message.text()); });
    });
    await context.tracing.start({ screenshots: true, snapshots: true, sources: true });
    const page = await context.newPage();
    await page.goto('http://localhost:4002/users/log_in');
    await page.locator('#user_email').fill(process.argv[2]);
    await page.locator('#user_password').fill(process.argv[3]);
    await Promise.all([
      page.waitForURL(url => url.pathname !== '/users/log_in'),
      page.locator('#login_form button').click()
    ]);
    await openLive(page, '/admin');
    await scenario({ page, context, expect, openLive });
    assert.deepEqual(errors, [], 'Uncaught browser JavaScript errors');
    console.log(`${name}: passed`);
  } catch (error) {
    failure = error;
    for (const [index, page] of (context?.pages() || []).entries()) {
      await page.screenshot({ path: path.join(directory, `page-${index}.png`), fullPage: true }).catch(() => {});
    }
    console.error(error);
    console.error(`Browser failure artifacts: ${directory}`);
    process.exitCode = 1;
  } finally {
    if (context) await context.tracing.stop(failure ? { path: path.join(directory, 'trace.zip') } : {}).catch(() => {});
    if (browser) await browser.close();
    await fs.writeFile(path.join(directory, 'result.json'), JSON.stringify({
      name, status: failure ? 'failed' : 'passed', durationMs: Date.now() - started,
      error: failure?.stack, pageErrors: errors, consoleErrors
    }, null, 2));
  }
}

module.exports = { runSmoke };
