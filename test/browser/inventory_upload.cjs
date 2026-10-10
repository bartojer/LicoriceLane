// Invoked by the browser case in inventory_upload_test.exs; persistence is checked there.
const assert = require('node:assert/strict');
const { runSmoke } = require('./smoke.cjs');
const png = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Y9ZlS8AAAAASUVORK5CYII=', 'base64');

runSmoke('inventory-upload', async ({ page, context, expect, openLive }) => {
  const publicPage = await context.newPage();
  await openLive(publicPage, '/inventory');
  await page.getByRole('button', { name: 'Add Item', exact: true }).click();
  await page.locator('#item-name').fill('Browser upload');
  await page.locator('#item-description').fill('Synthetic browser fixture');
  await page.locator('#add-item-form input[type=file]').setInputFiles({ name: 'browser.png', mimeType: 'image/png', buffer: png });
  const preview = page.locator('#add-item-form img[data-phx-hook="Phoenix.LiveImgPreview"]');
  const decoded = image => image.evaluate(img => img.complete && img.naturalWidth === 1 && img.naturalHeight === 1);
  await expect.poll(() => decoded(preview)).toBe(true);
  await expect(page.locator('#add-item-form input[type=file]')).toHaveCount(1);
  // Reject only after transfer; retry must use the same mounted selection.
  await page.locator('#item-condition').fill('');
  await page.getByRole('button', { name: 'Create Item', exact: true }).click();
  await expect(page.locator('#add-item-error')).toHaveText('Please check the item location and details.');
  await expect(preview).toHaveCount(1);
  await expect.poll(() => decoded(preview)).toBe(true);
  await expect(page.locator('#item-name')).toHaveValue('Browser upload');
  await page.locator('#item-condition').fill('New');
  await page.getByRole('button', { name: 'Create Item', exact: true }).click();
  const savedImage = page.getByRole('img', { name: 'Browser upload', exact: true });
  await expect(savedImage).toHaveAttribute('src', /^\/uploads\/[0-9a-f-]{36}\.png$/);
  await expect.poll(() => decoded(savedImage)).toBe(true);
  const source = await savedImage.getAttribute('src');
  const response = await page.request.get('http://localhost:4002' + source);
  assert.equal(response.status(), 200);
  assert.equal(response.headers()['content-type'].split(';')[0], 'image/png');
  assert.deepEqual(await response.body(), png);

  // A second connected page must receive the stream insert without reloading.
  const card = publicPage.locator('#items > a').filter({ has: publicPage.getByRole('img', { name: 'Browser upload', exact: true }) });
  await expect(card).toHaveCount(1);
  await expect(card.locator('img')).toHaveAttribute('src', source);
  await card.getByRole('heading', { name: 'Browser upload', exact: true }).click();
  await expect(publicPage).toHaveURL(/\/inventory\/\d+$/);
  await expect(publicPage.getByRole('dialog')).toBeVisible();
  await expect(publicPage.getByRole('dialog').getByRole('heading', { name: 'Browser upload', exact: true })).toBeVisible();
  await publicPage.keyboard.press('Escape');
  await expect(publicPage.getByRole('dialog')).toHaveCount(0);
  await expect(publicPage).toHaveURL('http://localhost:4002/inventory');
}).catch(error => { console.error(error); process.exitCode = 1; });
