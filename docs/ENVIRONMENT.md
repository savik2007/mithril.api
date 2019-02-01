## Environment Variables

This environment variables can be used to configure released docker container at start time.
Also sample `.env` can be used as payload for `docker run` cli.

### General

| VAR_NAME              | Default Value               | Description |
| --------------------- | --------------------------- | ----------- |
| ERLANG_COOKIE         | `mFd1nWJ1KUxj`..            | Erlang [distribution cookie](http://erlang.org/doc/reference_manual/distributed.html). **Make sure that default value is changed in production.** |
| LOG_LEVEL             | `info`                      | Elixir Logger severity level. Possible values: `debug`, `info`, `warn`, `error`. |
| RECAPTCHA_VERIFY_URL  | `https://www.google.com...` | ReCAPTCHA verify URL|

### Database

Currently there are two options to set DB connections settings.

**By setting a separate value for each option:**

| VAR_NAME      | Default Value | Description |
| ------------- | ------------- | ----------- |
| DB_NAME       | `mithril_api_dev` | Database name. |
| DB_USER       | `postgres`    | Database user. |
| DB_PASSWORD   | `postgres`    | Database password. |
| DB_HOST       | `travis`      | Database host. |
| DB_PORT       | `5432`        | Database port. |

**By setting a single connection URI:**

| VAR_NAME      | Default Value | Description |
| ------------- | ------------- | ----------- |
| DATABASE_URL  | not set       | Database URI. Example: `postgres://postgres:postgres@travis:5432/mithril_api_dev` |

If you want to run migrations when container starts, use a `DB_MIGRATE` variable:

| VAR_NAME      | Default Value | Description |
| ------------- | ------------- | ----------- |
| DB_MIGRATE    | `true`        | Migrate database when container starts. |

### Phoenix HTTP Endpoint

| VAR_NAME      | Default Value | Description |
| ------------- | ------------- | ----------- |
| PORT          | `4000`        | HTTP host for web app to listen on. |
| HOST          | `localhost`   | HTTP port for web app to listen on. |
| SECRET_KEY    | `mFd1nWJ1KUxj`.. | Phoenix [`:secret_key_base`](https://hexdocs.pm/phoenix/Phoenix.Endpoint.html). **Make sure that default value is changed in production.** |

## Token lifetime in seconds

| VAR_NAME                    | Default Value    | Description              |
| --------------------------- | ---------------- | ------------------------ |
| AUTH_CODE_GRANT_LIFETIME    | 300              | Lifetime of code grant   |
| AUTH_ACCESS_TOKEN_LIFETIME  | 2592000          | Lifetime of access token |
| AUTH_REFRESH_TOKEN_LIFETIME | 604800           | Lifetime of secret token |

## Two-factor authentication

| VAR_NAME                           | Default Value                   | Description              |
| ---------------------------------- | ------------------------------- | ------------------------ |
| USER_2FA_ENABLED                   | true                            | Create or not default auth factor for user|
| USER_LOGIN_ERROR_MAX               | 3                               | Max failed user login attempts until user will be blocked |
| USER_OTP_ERROR_MAX                 | 3                               | Max failed OTP verifications attempts until user will be blocked |
| OTP_LENGTH                         | 6                               | OTP code length |
| OTP_LIFETIME                       | 300                             | OTP lifetime in seconds |
| OTP_EXPIRATION_SCHEDULE            | */5 * * * *                     | Cron config for running OTP expiration tasks |
| OTP_MAX_ATTEMPTS                   | 3                               | Max attempts for verification OTP |
| OTP_SMS_TEMPLATE                   | "Код підтвердження: <otp.code>" | SMS template for verification OTP. <otp.code> will replaced to OTP code |
| TRUSTED_CLIENT_IDS                 | not set                         | Client ids, that allowed not to send scopes for app:authorize method. E.g. Cabinet client ID |
| SENSITIVE_DATA_IN_RESPONSE_ENABLED | false                           | Sensitive data in response for tests. E.g. sms code for auth |