# Cerca — backend

Rust API (axum + sqlx + Postgres) for the Cerca marketplace. Hexagonal
architecture, one folder per feature under `src/features/`, each split
into `domain` / `application` / `infrastructure` / `interfaces`.

## Running locally

```bash
docker compose up -d          # Postgres on :5433 (see ../docker-compose.yml)
cp .env.example .env          # then fill in DATABASE_URL and JWT_SECRET
cargo run
```

Migrations in `migrations/` run automatically at startup, so a fresh
database is ready after the first boot.

Migrations describe the schema only. Demo data (4 technicians, 1 client,
their profiles and teams) lives in `seeds/demo.sql` and is **opt-in**:

```bash
cargo run --bin seed           # load the demo fixture
```

It used to be part of migration 0002, which meant five accounts sharing the
hash of `password123` — and `password123` itself, in this file — existed in
**every** environment, production included. Two things changed:

* the seed block in migration 0002 is neutralised by migration 0011, which
  nulls those password hashes; and
* every demo account in `seeds/demo.sql` ships with a **NULL** password, so
  the fixture makes the app browsable without carrying a usable credential.

To sign in as a demo user locally, give it a password you choose:

```bash
cargo run --bin seed -- --hash 'my-local-password'
# then: UPDATE users SET password_hash = '<that hash>' WHERE email = 'client@cerca.com';
```

`APP_ENV=production` makes the server refuse to boot while any account still
carries the old public hash.

```bash
cargo test                    # needs the Postgres above running
```

Tests use `#[sqlx::test]`, which creates a throwaway database per test —
they never touch your development data.

## Environment variables

| Variable | Required | Notes |
|---|---|---|
| `DATABASE_URL` | yes | Server refuses to start without it |
| `JWT_SECRET` | yes | Changing it invalidates every existing session |
| `APP_ENV` | no | Set to `production` to enable the deployment guards (today: refuse to boot while a publicly-known demo password hash is still in the database) |
| `PORT` | no | Defaults to 8080; Render injects its own |
| `RUST_LOG` | no | Defaults to `backend=debug,tower_http=debug` |
| `CORS_ALLOWED_ORIGINS` | no | Comma-separated. Empty = no browser may call the API cross-origin, which is correct for a mobile-only client |
| `S3_*` | no | Document uploads answer 503 until these are set; everything else works |
| `GOOGLE_CLIENT_IDS` | no | Comma-separated OAuth client ids allowed in a Google ID token's `aud`. `/auth/google` answers 503 until set; everything else works |
| `PAYMENTS_MODE` | no | Defaults to `fake`: simulates fee capture, persists a row in `job_payments`, and returns `{ "simulated": true }`. The server **refuses to boot** with `APP_ENV=production` and `PAYMENTS_MODE=fake` — wire a real adapter before going live with money |

## Deploying

Hosting is declared in `../render.yaml` (Render Blueprint). Render
watches the default branch and redeploys on pushes that touch
`backend/**`. There is no deploy CI job — Render does it natively.

### 1. Database — Supabase Postgres

The API uses standard Postgres through `sqlx`, so Supabase is used as the
managed database without adding its SDK to Flutter or exposing database
credentials in the mobile app.

1. Create a Supabase project and keep its database password securely.
2. In the project dashboard, select **Connect → Session pooler**.
3. Copy the port `5432` connection string and replace `[YOUR-PASSWORD]`.
4. Add `?sslmode=require` if the copied URL does not already specify SSL.
5. Paste the complete URL as `DATABASE_URL` in Render and redeploy.

Render is a persistent backend and can be IPv4-only, which is why Session
pooler is preferred over the direct IPv6 endpoint. Do not use Transaction
pooler on port `6543`: it does not support prepared statements. On first
startup the API applies every file in `backend/migrations/` automatically.

Changing `DATABASE_URL` starts with an empty database unless the existing
Postgres data is exported and restored first. The schema migrates
automatically; existing users and jobs do not.

### 2. Document storage — Supabase Storage

Any S3-compatible provider works (R2, Backblaze B2, MinIO, AWS); only
these variables change. Current choice is Supabase Storage: 1 GB free,
no card.

1. Create a Supabase project.
2. Storage → new bucket, **private** (these are identity documents —
   never make this bucket public).
3. Project Settings → Storage → S3 access keys → generate one.
4. Set in Render:

   ```
   S3_ENDPOINT=https://<project-ref>.supabase.co/storage/v1/s3
   S3_REGION=<the region shown in project settings>
   S3_ACCESS_KEY_ID=<generated>
   S3_SECRET_ACCESS_KEY=<generated>
   S3_BUCKET=<bucket name>
   ```

The API only ever *signs* URLs — file bytes go straight from the
technician's device to the bucket and never through this server. Bucket
CORS only matters if the Flutter **web** build is used; native Android
and iOS builds are not subject to it.

Note: a free Supabase project pauses after about a week without
activity and needs to be resumed from the dashboard.

### 3. Render

1. New → Blueprint, point it at this repo; it reads `../render.yaml`.
2. Fill in the variables marked `sync: false` when prompted.
3. `JWT_SECRET` is generated by Render — leave it alone.

The free instance sleeps after roughly 15 minutes of inactivity, so the
first request after a quiet period takes ~50 s while the container
starts. Everything after that is normal speed.

### Pointing the app at it

The Flutter client defaults to `http://10.0.2.2:8080` (the Android
emulator's alias for the host). For a deployed backend:

```bash
flutter run --dart-define=API_BASE_URL=https://<service>.onrender.com
```
