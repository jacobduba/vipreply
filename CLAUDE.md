# CLAUDE.md

## Current Account
The current account is available as an instance variable `@account` defined in `application_controller.rb:13`. This is set by the `authorize_account` before_action which finds the account from the session and handles authentication/token refresh.