# CLAUDE.md

## Current Account
The current account is available as an instance variable `@account` defined in `application_controller.rb:13`. This is set by the `authorize_account` before_action which finds the account from the session and handles authentication/token refresh.

## Route Format Constraints
User-facing routes are constrained to `html|turbo_stream` formats only for security, with OAuth callbacks and webhooks exempt as they receive external data formats. If you encounter issues with non-HTML/Turbo Stream formats, this is intentional - add explicit format support only if absolutely required.

## Database Migrations
This app uses multiple databases. When rolling back migrations, you must use:
- `rails db:rollback:primary` for the main database
- `rails db:rollback:queue` for the queue database
Using plain `rails db:rollback` will fail with an error.

## Trial Warning System
The header displays a trial warning for users with `@account.trialing?` status. The warning shows remaining days and links to the checkout page:
- Shows "X days left in trial" for active trials
- Only displays when trial has days remaining (expired trials are redirected away from navbar)
- Links to `checkout_subscribe_path` with `data: { turbo: false }` to redirect to Stripe checkout
- Trial status is based on `@account.subscription_period_end` compared to current date

## Billing Status Flow
Account billing statuses (defined in `account.rb`):
- `setup` → `trialing` (30 days) → `trial_expired` → `active` (after payment)
- `active` can become `past_due`, `unpaid`, `canceled`, etc. based on Stripe webhooks
- `has_access?` method returns true for `trialing?` or `active?` accounts
