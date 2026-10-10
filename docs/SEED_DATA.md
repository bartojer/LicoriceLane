# Disposable development samples

To update the schema and replace sample business data:

```text
mix ecto.migrate
mix run priv/repo/seeds.exs
```

The seed script replaces customers, messages, inventory, locations, bookings,
allocations and movement history in one transaction. Login accounts and tokens
stay available. Use these commands only for disposable data. A full
`mix ecto.reset` also drops login accounts because it recreates the whole database.

The sample set contains six fictional customers, two warehouses, six customer
venues, sixteen inventory items, three enquiries, and six managed bookings:

| Example | Behavior to try |
| --- | --- |
| Reserved wedding | Future reservation with napkins from both warehouses; edit allocations, reschedule or cancel |
| Active birthday | Checked-out single and bulk items; record partial or full returns |
| Partially returned wedding | Some napkins/tablecloths returned to their source; other units and a chandelier remain out |
| Overdue corporate event | Past due date with stock still out; return it from the Late filter |
| Returned birthday | Completed allocation counters and checkout/return history; stock restored |
| Cancelled corporate event | Retained allocation references with no stock movement |

Dates are relative to seed execution, so reseeding refreshes the demo windows.
Creation, checkout, returns and cancellation use the application contexts. Only
historical sample timelines are shifted after those operations to simulate elapsed
time; quantities, locations, allocation counters and movement endpoints remain as
produced by the contexts. Seeds do not infer legacy source warehouses. Every sample
booking is managed and can use the applicable stock actions immediately.

The LED candles provide a low-stock example. Customer/message contact values are
fictional, encrypted through their contexts, and populated with exact-lookup hashes.
Seeds do not provision an admin account; use the [local bootstrap](../README.md#local-admin-access).

The [seed contract regression](../test/licorice_lane/demo_seeds_test.exs) tests the
seeder itself inside a rollback sandbox. It checks repeated replacement, account
preservation, stock conservation/ownership, history and event chronology, lookup
hashes, and immediate cancellation/returns. Ordinary feature tests continue to use
fixtures. Run it with `mix test test/licorice_lane/demo_seeds_test.exs --seed 0`.

On October 10, 2026, the additive rental migration and updated seed script ran
successfully against the local `licorice_lane_dev` database.

The exact staged seed changes passed formatting, assets and all 410 regression
cases (408 server cases plus the two required browser regressions, with no skips).
