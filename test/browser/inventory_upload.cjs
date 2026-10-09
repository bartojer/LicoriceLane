// Invoked by the optional browser case in inventory_upload_test.exs.
// Use an installed Playwright module and browser; no npm install is required.
const assert = require('node:assert/strict');
const { chromium } = require(process.argv[4] || 'playwright');

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
    await page.getByRole('button', { name: 'Add Item', exact: true }).click();
    await page.locator('#item-name').fill('Browser upload');
    await page.locator('#item-description').fill('Synthetic browser fixture');
    await page.locator('#add-item-form input[type=file]').setInputFiles({
      name: 'browser.png', mimeType: 'image/png',
      buffer: Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Y9ZlS8AAAAASUVORK5CYII=', 'base64')
    });
    await page.waitForFunction(() => {
      const preview = document.querySelector('#add-item-form img[data-phx-hook="Phoenix.LiveImgPreview"]');
      return preview && preview.complete && preview.naturalWidth > 0;
    });
    assert.equal(await page.locator('#add-item-form input[type=file]').count(), 1);
    // Force a context/location-data rejection after the transfer has completed.
    await page.locator('#item-condition').fill('');
    await page.getByRole('button', { name: 'Create Item', exact: true }).click();
    await page.getByText('Please check the item location and details.', { exact: true }).waitFor();
    assert.equal(await page.locator('#add-item-form img[data-phx-hook="Phoenix.LiveImgPreview"]').count(), 1);
    await page.locator('#item-condition').fill('New');
    await page.getByRole('button', { name: 'Create Item', exact: true }).click();
    await page.locator('img[src^="/uploads/"]').waitFor();
    const source = await page.locator('img[src^="/uploads/"]').first().getAttribute('src');
    const response = await page.request.get('http://localhost:4002' + source);
    assert.equal(response.status(), 200);
    assert.equal(response.headers()['content-type'].split(';')[0], 'image/png');
    assert.deepEqual(errors, []);
    console.log('Browser selection, decoded preview, transfer, rejected save, retry, and saved image: passed');
  } finally {
    await browser.close();
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
