# TrueNorth119 OAuth2 + OIDC Starter (development only)

This **example starter** contains:

- `truenorth119-auth`: Spring Security Authorization Server (port **9000**), local demo account, OAuth2/OIDC Authorization Code + PKCE, JWT signing.
- `truenorth119-api`: Spring Boot Resource Server (port **8080**) that validates the token's signature, issuer, expiry, scope and audience; connects to your **MySQL `truenorth119`** database.
- `truenorth119-web`: Vite + React sample (port **5173**), using `oidc-client-ts`.
- `database/`: your earlier MySQL schema and a **run-once** migration adding the OIDC subject fields to `users`.

**Requires:** Java 21, Maven, Node.js 20.19+ or 22.12+, npm, MySQL 8.0.16+, MySQL Workbench.

All three applications must consistently use **127.0.0.1** (not `localhost`) for their configured development URLs.

## 1. MySQL in Workbench

If the initial database does not exist, run `database/001_initial_schema.sql` once (this is a fresh database schema!).

Then run `database/002_add_oauth_identity.sql` **exactly once**, against the `truenorth119` database. If you've already added `auth_issuer` and `auth_subject`, do not run the migration again.

Create a dedicated MySQL account, with a strong password of your own (don't commit it to Git):

```sql
CREATE USER 'truenorth_app'@'localhost' IDENTIFIED BY 'replace-with-a-strong-password';
GRANT SELECT, INSERT, UPDATE, DELETE ON truenorth119.* TO 'truenorth_app'@'localhost';
```

Depending on how your MySQL server resolves 127.0.0.1, you may also need an account with host `127.0.0.1`, or instead change the JDBC URL to `localhost` in `truenorth119-api/src/main/resources/application.yml`. This change is unrelated to OAuth issuer URLs.

## 2. Start the authorization server

In terminal 1:

```bash
cd truenorth119-auth
mvn spring-boot:run
```

Open http://127.0.0.1:9000/.well-known/openid-configuration and confirm metadata appears. The OAuth2 server includes a **development-only** account: `demo` / `dev-only-password`.

To change that password, set `DEMO_PASSWORD` before startup (recommended even for private dev):

PowerShell: `$env:DEMO_PASSWORD = "my-local-test-password"`

**Never expose this demo auth service to the public internet.** Its RSA signing keys, registered client and demo account are in-memory. Restarting rotates its key and invalidates old access tokens.

## 3. Start the secured REST API

In terminal 2 set your DB credentials and run:

PowerShell:

```powershell
$env:DB_USERNAME = "truenorth_app"
$env:DB_PASSWORD = "your-database-password"
cd truenorth119-api
mvn spring-boot:run
```

Bash:

```bash
export DB_USERNAME=truenorth_app
export DB_PASSWORD='your-database-password'
cd truenorth119-api
mvn spring-boot:run
```

Unauthenticated request test (should be `401`):

`curl -i http://127.0.0.1:8080/api/me`

If you see a connection failure, confirm MySQL Server is running, schema exists, and credentials work. Workbench is a SQL editor, not the server process itself.

## 4. Start React

In terminal 3:

```bash
cd truenorth119-web
npm install
npm run dev
```

Open http://127.0.0.1:5173 and click **Sign in**. Use the development credentials from step 2. Click **Test secured API** to call `/api/me`; then click **Create / load MySQL profile** to call `/api/profile`. Check MySQL Workbench with:

```sql
SELECT id, username, auth_issuer, auth_subject FROM truenorth119.users;
```

## 5. First milestone checklist

- Auth server discovery metadata responds at `/.well-known/openid-configuration`.
- `GET /api/me` with no access token returns **401**.
- React redirects to the auth server and returns to `/callback` after successful login.
- React `Test secured API` displays **200** and the authenticated subject.
- React `Create / load MySQL profile` displays **200** and a MySQL user record.

## Design / production TODOs

This is **not production-ready**. Before deploying: persist and rotate signing keys securely, use HTTPS, store registered clients and authorizations in a persistent database, implement durable account registration and secure password reset, rate limiting, MFA and anti-abuse, replace demo user, customize `sub` to a stable immutable account identifier, implement concurrency-safe first-login provisioning, observability, migrations with Flyway, hardened scopes/consent, logout/session controls and secure token lifecycle. For browser production use a Backend-for-Frontend where practical, with HttpOnly cookies and CSRF protection, or carefully secure the public PKCE SPA per RFC 10017. For React Native register a separate public PKCE client and use external system browser and OS secure storage.

Don't store passwords or access tokens in your `users` table. Don't use a caller-provided user ID to authorize theme access. Use `jwt.getIssuer()` and `jwt.getSubject()` to resolve the signed-in user and check owner/share permissions for **every** themes/verses query.

This starter was authored from current official documentation but **could not be compiled/executed in the authoring environment** (Maven dependencies were unavailable). Resolve any dependency/API differences against Spring Boot 4.1.2 and Spring Security 7.1.2 official documentation.

### Sources

- https://docs.spring.io/spring-security/reference/servlet/oauth2/authorization-server/getting-started.html
- https://docs.spring.io/spring-security/reference/servlet/oauth2/resource-server/jwt.html
- https://docs.spring.io/spring-boot/reference/using/build-systems.html
- https://www.rfc-editor.org/rfc/rfc10017.html
- https://www.rfc-editor.org/rfc/rfc8252.html
