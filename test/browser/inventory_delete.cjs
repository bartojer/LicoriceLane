// Invoked by the optional browser case in admin_inventory_delete_test.exs.
const assert = require('node:assert/strict');
const { chromium } = require(process.argv[4] || 'playwright');
const { expect } = require((process.argv[4] || 'playwright') + '/test');

(async () => {
  const browser = await chromium.launch({
    headless: true,
    ...(process.argv[5] ? { executablePath: process.argv[5] } : {})
  });
  try {
    const page = await browser.newPage();
    const errors = [];
    page.on('pageerror', error => errors.push(error.message));
    await page.goto('http://localhost:4002/users/log_in');
    await page.locator('#user_email').fill(process.argv[2]);
    await page.locator('#user_password').fill(process.argv[3]);
    await Promise.all([
      page.waitForURL(url => url.pathname !== '/users/log_in'),
      page.locator('#login_form button').click()
    ]);
    await page.goto('http://localhost:4002/admin');
    await page.waitForFunction(() => document.querySelector('[data-phx-main]')?.classList.contains('phx-connected'));
    await page.getByRole('button', { name: 'Inventory', exact: true }).click();

    const dialog = page.getByRole('dialog');
    const singleRow = page.locator('#inventory-item-' + process.argv[6]);
    await singleRow.getByRole('button', { name: 'Delete', exact: true }).click();
    await expect(dialog).toBeVisible();
    await dialog.getByRole('button', { name: 'Cancel', exact: true }).click();
    await expect(dialog).toHaveCount(0);
    await expect(singleRow).toBeVisible();

    // Escape exercises the modal's JavaScript on_cancel command.
    await singleRow.getByRole('button', { name: 'Delete', exact: true }).click();
    await expect(dialog).toBeVisible();
    await page.keyboard.press('Escape');
    await expect(dialog).toHaveCount(0);
    await expect(singleRow).toBeVisible();

    for (const id of process.argv.slice(6, 8)) {
      const row = page.locator('#inventory-item-' + id);
      await row.getByRole('button', { name: 'Delete', exact: true }).click();
      await expect(dialog).toBeVisible();
      await dialog.getByRole('button', { name: 'Delete item', exact: true }).click();
      await expect(dialog).toHaveCount(0);
      await expect(row).toHaveCount(0);
      await expect(page.locator('#inventory-delete-notice')).toHaveText('Item deleted successfully.');
    }
    assert.deepEqual(errors, []);
    console.log('Browser cancel, Escape, and confirmed single/bulk deletion: passed');
  } finally {
    await browser.close();
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
