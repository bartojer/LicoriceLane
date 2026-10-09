# Historical admin dashboard refactor

This file summarizes the original refactor plan. It is historical context, not an implementation checklist. Reviewed against the working tree on October 7, 2026; use [current status](docs/STATUS.md) for unfinished work and [architecture](docs/ARCHITECTURE.md) for current paths and contracts.

## Original goals now represented in code

- Replace mock dashboard data with inventory, customer, and rental queries.
- Split the admin shell into tab-specific LiveComponents.
- Add rental event type/date fields and item minimum-stock thresholds.
- Show warehouse quantity breakdowns and low-stock information.
- Broadcast inventory changes and subscribe from public inventory browsing.

The application now also includes messages, item add/edit forms with image uploads, pagination, shared admin helpers, and cache invalidation infrastructure.

## Current implementation map

| Concern | Current entry point |
| --- | --- |
| Admin shell and tab navigation | [admin_live.ex](lib/licorice_lane_web/live/admin/admin_live.ex) |
| Inventory and warehouse queries | [inventory.ex](lib/licorice_lane/inventory.ex) |
| Customer queries and writes | [customers.ex](lib/licorice_lane/customers.ex) |
| Booking queries | [rentals.ex](lib/licorice_lane/rentals.ex) |
| Rental schema | [rentals/rental.ex](lib/licorice_lane/rentals/rental.ex) |
| Item schema | [items/item.ex](lib/licorice_lane/items/item.ex) |
| Shared formatting and pagination metadata | [admin_helpers.ex](lib/licorice_lane_web/helpers/admin_helpers.ex) |
| Pagination controls | [pagination.ex](lib/licorice_lane_web/components/pagination.ex) |
| Admin authentication and authorization | [router.ex](lib/licorice_lane_web/router.ex), [user_auth.ex](lib/licorice_lane_web/user_auth.ex) |

## Corrections to the original plan

- Bookings and rentals are one entity, but the Rentals context currently offers read operations only.
- Single items and bulk quantity tracking both remain supported; bulk quantities are represented by `ItemsLocation` rows.
- Upcoming queries use future `rented_at`; active queries check stored status without excluding future dates.
- Customer name supports substring search; encrypted email/phone use exact SHA256 hash lookups.
- Pagination is implemented in current list contexts/components.
- Cachex startup and write invalidation exist; query caching is not currently integrated.
- Admin realtime refresh is not established by component subscriptions alone. PubSub messages arrive at the parent LiveView; see the [refresh gap](docs/STATUS.md#verification-gaps).

## Remaining work

Inventory deletion in the admin UI, booking date filtering/details/updates, customer details/editing, and rental lifecycle write operations remain unfinished. See [the current workflow table](docs/STATUS.md#unfinished-workflows) for source entry points. The original unchecked testing checklist should not be used as evidence that checks passed or that completed code still needs to be built.
