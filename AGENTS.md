# AGENTS.md

Purpose: quick context and guardrails for AI coding agents (e.g., Codex) working in this repo. Keep changes focused, safe, and aligned with the existing style.

## Quick Start
- Run app: `bin/dev` (db auto-prepared via `bin/rails db:prepare`)
- One-shot setup: `bin/setup` (installs gems, prepares DB, clears logs; starts server unless `--skip-server`)
- Tests: `bin/rails test`
- Lint: `bin/lint` (StandardRB; add `--fix` to auto-fix)
- Security scan (optional): `bin/brakeman`

## Agent Guardrails
- Keep diffs minimal: fix the root cause, avoid unrelated refactors.
- Match style: Ruby 3.4, StandardRB formatting, idiomatic Rails.
- Don’t add dependencies or services without approval.
- Don’t change licenses or headers; don’t expose secrets.
- Prefer `rg` for search; keep edits localized and reversible.

## App Context

### Current Account
The current account is available as an instance variable `@account` defined in `application_controller.rb:13`. This is set by the `authorize_account` before_action which finds the account from the session and handles authentication/token refresh.

#### Account Methods
- `@account.trialing?` - Returns true if account is in trial period
- `@account.trial_days_remaining` - Returns the number of days remaining in trial (returns 0 if not trialing or no trial days left)
- `@account.has_access?` - Returns true if account is trialing or active (has access to the app)
- `@account.subscription_period_end` - DateTime when current subscription/trial period ends

### Route Format Constraints
User-facing routes are constrained to `html|turbo_stream` formats only for security, with OAuth callbacks and webhooks exempt as they receive external data formats. Add explicit format support only if absolutely required.

### Database Migrations
This app uses multiple databases. When rolling back migrations, use:
- `rails db:rollback:primary` for the main database
- `rails db:rollback:queue` for the queue database
Using plain `rails db:rollback` will fail with an error.

### Trial Warning System
The header displays a trial warning for users with `@account.trialing?` status. The warning shows remaining days and links to the checkout page:
- Shows "X days left in trial" for active trials
- Only displays when trial has days remaining (expired trials are redirected away from navbar)
- Links to `checkout_subscribe_path` with `data: { turbo: false }` to redirect to Stripe checkout
- Trial status is based on `@account.subscription_period_end` compared to current date

### Billing Status Flow
Account billing statuses (defined in `account.rb`):
- `setup` → `trialing` (30 days) → `trial_expired` → `active` (after payment)
- `active` can become `past_due`, `unpaid`, `canceled`, etc. based on Stripe webhooks
- `has_access?` returns true for `trialing?` or `active?` accounts

## Handy Paths
- Rails entrypoints: `bin/rails`, `bin/dev`, `bin/setup`
- Tests: `test/` (Minitest)
- Lint: `bin/lint` (StandardRB)
- Webhooks helper: `bin/stripe`

## When In Doubt
- Ask before changing routes, DB schemas, or billing logic.
- Prefer small PRs; include steps to reproduce and test notes.
