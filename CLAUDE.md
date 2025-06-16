# CLAUDE.md

## Current Account
The current account is available as an instance variable `@account` defined in `application_controller.rb:13`. This is set by the `authorize_account` before_action which finds the account from the session and handles authentication/token refresh.

## Route Format Constraints
User-facing routes are constrained to `html|turbo_stream` formats only for security, with OAuth callbacks and webhooks exempt as they receive external data formats. If you encounter issues with non-HTML/Turbo Stream formats, this is intentional - add explicit format support only if absolutely required.