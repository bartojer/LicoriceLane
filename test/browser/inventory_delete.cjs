// Invoked by the browser case in admin_inventory_delete_test.exs; stock cleanup is checked there.
const { runSmoke } = require('./smoke.cjs');

runSmoke('inventory-delete', async ({ page, context, expect, openLive }) => {
  const publicPage = await context.newPage();
  await openLive(publicPage, '/inventory');
  const ids = process.argv.slice(6, 8);
  for (const id of ids) await expect(publicPage.locator('#items-' + id)).toBeVisible();
  await page.getByRole('button', { name: 'Inventory', exact: true }).click();
  const dialog = page.getByRole('dialog');
  const rowFor = id => page.locator('#inventory-item-' + id);
  const requestDelete = async id => {
    const row = rowFor(id);
    const name = await row.locator('td').nth(1).locator('div').first().textContent();
    await row.getByRole('button', { name: 'Delete', exact: true }).click();
    await expect(dialog).toBeVisible();
    await expect(dialog.locator('#delete-item-modal-title')).toHaveText(`Delete ${name.trim()}?`);
  };
  // Cancel and Escape independently exercise the modal's server event and JS on_cancel.
  for (const cancel of [
    () => dialog.getByRole('button', { name: 'Cancel', exact: true }).click(),
    () => page.keyboard.press('Escape')
  ]) {
    await requestDelete(ids[0]);
    await cancel();
    await expect(dialog).toHaveCount(0);
    for (const id of ids) {
      await expect(rowFor(id)).toBeVisible();
      await expect(publicPage.locator('#items-' + id)).toBeVisible();
    }
  }
  for (const id of ids) {
    await requestDelete(id);
    await dialog.getByRole('button', { name: 'Delete item', exact: true }).click();
    await expect(dialog).toHaveCount(0);
    await expect(rowFor(id)).toHaveCount(0);
    await expect(page.locator('#inventory-delete-notice')).toHaveText('Item deleted successfully.');
    await expect(publicPage.locator('#items-' + id)).toHaveCount(0);
  }
}).catch(error => { console.error(error); process.exitCode = 1; });
