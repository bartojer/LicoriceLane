# Inventory image upload investigation

Historical investigation from October 7, 2026 against the then-current working tree, including the existing uncommitted upload implementation. The findings and diagnostic results below describe the behavior before repairs. On October 9, the local upload flow was repaired: persistent inputs, one-time initialization, postponed consumption on failed saves, shared configurable local storage, atomic single-item edits, and saved thumbnails. Current behavior and regression coverage are documented in [ARCHITECTURE.md](ARCHITECTURE.md), [STATUS.md](STATUS.md), and [README.md](../README.md). The ignored diagnostic file intentionally asserts the old bugs and should not be used as a regression suite after these fixes.

## Conclusion

The current upload flow has concrete implementation bugs. The strongest explanation for selection/preview/upload failure is that both add and edit forms remove their LiveView file input immediately after a file is selected. A separate confirmed save/retry bug loses an uploaded image after item validation fails. The database field and context do preserve image paths when given valid input.

Keep Phoenix LiveView for uploads. Fix the form and upload lifecycle first. A storage abstraction would improve consistency; replacing the upload library is not required to correct the confirmed failures.

## Current flow

1. The admin component allows one JPG/JPEG/PNG/GIF/WebP image, at most 10,000,000 bytes.
2. File selection creates a LiveView upload entry and triggers form validation. `auto_upload` is not enabled, so transfer normally happens during form submission. A preview at this stage does not mean a file is stored.
3. On submission, LiveView's client is supposed to transfer the file before invoking `save`.
4. The add handler copies the completed temporary file into the application's `priv/static/uploads` directory and consumes the entry.
5. The handler passes `/uploads/<filename>` as `image_path` into `Inventory.create_item_with_location/1`. Ecto inserts the item and location data in one database transaction.
6. `Plug.Static` serves `/uploads/...`, and inventory views use the saved path in `<img src>`.

Only `items.image_path` is stored in PostgreSQL. The image bytes are local files. There is no image table, binary image column, or external storage adapter in this implementation.

## Findings

### 1. The file input disappears after selection — primary failure

Sources:

- [Add form](../lib/licorice_lane_web/live/admin/add_item_component.ex), lines 362–391.
- [Edit form](../lib/licorice_lane_web/live/admin/edit_item_component.ex), lines 307–336.

Both templates put `<.live_file_input>` inside `if Enum.empty?(@uploads.image.entries)`. Selecting a file makes that condition false: the next render removes the input and displays `<.live_img_preview>` instead.

The installed LiveView 1.1.16 JavaScript depends on that input:

- `hooks.js`, `LiveImgPreview.mounted`, looks it up by the upload reference.
- `live_uploader.js`, `activeFileInputs` and `inputsAwaitingPreflight`, find files through upload inputs still inside the form.
- `view.js`, `pushFormSubmit`, decides whether it needs to transfer files by inspecting those inputs.

Confirmed with the actual authenticated `/admin` components: the file input exists before selection and is absent after selection, for both add and edit. With a pending add upload, a directly simulated submit reaches the rescue path with `cannot consume uploaded files when entries are still in progress`, and no item is inserted.

The expected browser consequences are broken preview lookup and skipped file transfer. That explanation is based on the rendered DOM and installed JavaScript source; no graphical browser end-to-end reproduction is claimed.

**Repair:** Keep the same file input mounted throughout selection, preview, progress, errors, cancellation, and save. Hide or replace only the surrounding instructions. Simply enabling auto-upload does not repair a disappearing input.

### 2. Failed creation consumes the image; retry saves a placeholder — confirmed

Sources: [Add handler](../lib/licorice_lane_web/live/admin/add_item_component.ex), lines 92–154 and 584–618.

The image is copied and consumed before the item/context validates and saves. If item validation fails, the file remains on disk but the upload entry is gone. The next submit sees no upload and unconditionally replaces `image_path` with `/images/placeholder.png`.

A diagnostic component kept the input mounted while delegating to the original add component's update and event handlers. Uploading a real PNG, submitting a blank name, then correcting the name reproduced:

- Failed first save: no item, completed upload consumed, copied image left on disk.
- Successful retry: item saved with the placeholder path; copied image remained unlinked.

This can also happen after location or quantity failures. Edit consumes uploads before saving too and needs the same lifecycle review.

**Repair:** Validate before finalizing the upload where possible. Preserve staged image state across failed saves, and coordinate successful database persistence with upload consumption and cleanup. Filesystem operations are not rolled back by the Ecto transaction. Preserve or explicitly discard the staged image on every error path.

### 3. Component updates can reset or crash an active upload — confirmed callback behavior

Sources: add `update/2`, lines 11–27; edit `update/2`, lines 8–22.

Both callbacks unconditionally call `allow_upload(:image, ...)` and reset form state whenever the component receives an update. LiveView raises if `allow_upload` is called for an upload with active entries. A direct callback diagnostic confirmed this exception for add.

AdminLive receives message events and changes its message count; parent updates should be checked as an interruption case in a permanent regression test. An actual message-triggered crash was not separately reproduced.

**Repair:** Initialize uploads once in `mount/1` or guard initialization, and preserve active form/upload state during routine parent updates. Deliberately reset edit state when switching items.

### 4. Add/edit storage is inconsistent — source-confirmed, deployment-dependent

Add writes to `:code.priv_dir(:licorice_lane)/static/uploads` and creates the directory. Edit writes to working-directory-relative `priv/static/uploads`, assumes the directory exists, and uses `File.cp!` without an error handler. These paths happen to resolve to the same directory in the inspected WSL development/test builds, but that is not a reliable release contract. A missing or unwritable edit destination raises and disconnects the LiveView.

Local files also require persistent writable storage, backups, and a plan for multiple application instances. The repo has no such configuration. Generated names combine a process-local unique integer and a hash of the original filename; UUID-based keys would avoid relying on process lifetime for uniqueness.

**Repair:** Share one configured storage service for add and edit, use globally unique keys, and define replacement/deletion/error cleanup. For deployment, use a persistent volume with explicit serving configuration or object storage.

### 5. The success preview does not display the saved image — source-confirmed

The add success card at lines 186–187 displays a category emoji. It never uses `@created_item.image_path`, even after a successful save. This makes visual confirmation misleading.

**Repair:** Display the saved image in the success card and provide an explicit fallback if no image exists.

## What worked

- `Item` defines `image_path`, includes it in its changeset, and the migration adds the column.
- The context preserved an explicit image path for both single and bulk item creation.
- The current `static_paths/0` includes `uploads`.
- With the diagnostic input kept mounted, the original add save handler stored a `/uploads/...` path in PostgreSQL, copied identical image bytes, and served the URL with HTTP 200.
- Uploads are already excluded from the development live-reload pattern.

These results isolate the main failures to form/lifecycle logic rather than an inherently unsuitable database architecture.

## Historical version caveat

The inspected committed `HEAD` differs materially from the working tree: its add component has no file upload implementation, and its static path allowlist omits `uploads`. It uses a placeholder path by default. The current upload code is in existing local changes. This could explain failures in an older running build, but it does not establish which version was running during any past attempt.

## Library and architecture assessment

Phoenix LiveView already supports progress, previews, cancellation, accepted types, and direct-to-cloud uploads. Its [official upload guide](https://hexdocs.pm/phoenix_live_view/uploads.html) describes the client transferring files before the submit callback and cautions against relying on local instance storage in production. The [external uploads guide](https://hexdocs.pm/phoenix_live_view/external-uploads.html) documents S3 and compatible object storage.

[Waffle](https://hexdocs.pm/waffle/Waffle.Storage.S3.html) is an option for organizing attachment storage and S3 integration through ExAws. It would be an additional storage layer here, and would still require correcting the component lifecycle. For one image per item, my recommendation is to retain LiveView and introduce a small shared storage service first; consider Waffle if image variants or richer attachment handling become requirements.

## Validation and next implementation scope

The ignored [diagnostic file](../tmp/image_upload_investigation_test.exs) contains six checks, run in Ubuntu WSL with Elixir 1.18.4 / OTP 28.0.2 and the existing SQL Sandbox test database:

| Check | Observed result |
| --- | --- |
| Actual add form after selection | Input removed; pending upload cannot be consumed; no item inserted |
| Actual edit form after selection | Input removed |
| Original add handler with persistent test input | Database path, file bytes, and HTTP 200 verified |
| Invalid save followed by corrected retry | Placeholder persisted; image left unlinked |
| Add update callback with active entry | `allow_upload` exception verified |
| Context creation for single/bulk | Provided image path preserved |

Command: `mix test tmp/image_upload_investigation_test.exs --seed 0`, with the README's WSL environment settings. Final result: **6 tests, 0 failures**. These checks assert observed broken behavior as well as working behavior; they are evidence for the diagnosis, not proof of a repair. The probe component bypasses the template defect solely to isolate the existing server save logic.

All fixture database changes were sandboxed. Diagnostic image files were removed; `priv/static/uploads` contains only its original `.gitkeep`. No seeds, database resets, or production writes were used.

A focused implementation should fix the persistent file input and one-time upload initialization, make failed-save retries preserve the image, unify storage/error handling, and display the saved thumbnail. Permanent tests should assert the corrected behavior, including a browser test for selection → preview → transfer → save, failed validation/retry, cancellation, and parent updates. Deployment storage can then be selected without blocking the local correctness fixes.
