# Deployment guide

CrowdDJ is a static web app (Flutter Web) plus a Supabase project. There is no server of your own to run.

## 1. Create a separate production Supabase project
Use a different project from development so test rooms and users never mix with real ones.

1. **Authentication, Sign In / Providers**: enable **Anonymous Sign-Ins**.
2. **Authentication, Rate Limits**: lower the anonymous sign-in rate limit (per IP per hour) to something your traffic justifies. Anonymous users count toward monthly active users.
3. **Authentication, Attack Protection**: enable **captcha** (Cloudflare Turnstile or hCaptcha) *only together with* the client change that obtains and passes a captcha token to `signInAnonymously`. Enabling it without that change makes every sign-in fail. Until then rely on rate limits.
4. **Project Settings, Realtime**: turn **off** "Allow public access" so private-channel authorization (migration 4) is enforced for every channel.
5. **Authentication, URL Configuration**: set the Site URL to your production origin.
6. Note the project URL and the **publishable** key (Project Settings, API Keys). Never use or commit the secret / `service_role` key.

## 2. Apply the database migrations
Prefer the Supabase CLI over the SQL editor (the editor runs statements separately and has left a database half-migrated before):

```bash
supabase link --project-ref <prod-ref>
supabase db push
```
Migrations are in `supabase/migrations/`, applied in order. Verify with the Dashboard **Advisors** (Security and Performance) and with the live check:

```bash
SUPABASE_URL=https://<prod-ref>.supabase.co SUPABASE_PUBLISHABLE_KEY=<key> node tool/live_security_check.mjs
```
Expected: `41 checks, 0 failed`. It creates two short-lived rooms and a few anonymous users, and closes the rooms at the end.

### Scheduled cleanup
Rooms expire after 24 hours but nothing deletes them. Enable the `pg_cron` extension (Dashboard, Database, Extensions) and schedule:

```sql
select cron.schedule('purge-stale-rooms', '17 3 * * *', $$select public.purge_stale_rooms()$$);
```
`purge_stale_rooms()` removes rooms closed or expired for more than 7 days (songs, queue, recommendations, votes and participants cascade). It is not callable by clients. Anonymous users are not purged automatically; remove old ones periodically from the Dashboard (Authentication) or with a service-side job if their count matters for MAU billing.

## 3. Build
```bash
cp env/prod.example.json env/prod.json      # fill in the PRODUCTION url and publishable key (git-ignored)
tool/build_web.sh env/prod.json --check     # analyze + test, then build into build/web
```
The script refuses to build when the config is missing or the key is a secret/service-role key, builds with `--release --no-web-resources-cdn` (CanvasKit and fallback fonts are served from your own origin, so the CSP needs no third-party hosts), and scans the output for leaked secrets. Add `--base-href /sub/path/` only when not serving from the domain root.

Output sizes (typical): `main.dart.js` ~3 MB raw / ~0.9 MB gzip, `canvaskit.wasm` ~5 MB raw (compressed by the host), four Latin font subsets of 38 KB each. Assets, including the demo MP3s, load on demand.

## 4. Host `build/web`
Two things are mandatory on any host: **deep links must serve `index.html`** (otherwise opening `/room/<code>` in a new tab 404s), and the **cache and security headers** below. Configs for four hosts are generated from one source, `tool/hosting.py`; edit headers there and run `python3 tool/hosting.py`.

| Host | Config | Deploy |
|---|---|---|
| Firebase Hosting | `firebase.json` | `firebase deploy --only hosting` |
| Vercel | `vercel.json` | deploy the `build/web` output directory |
| Netlify | `netlify.toml` | publish `build/web` |
| nginx | `docs/deploy/nginx.conf` | copy `build/web` to the web root |

Headers applied everywhere: `Content-Security-Policy`, `X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy`, `Permissions-Policy`, `Cross-Origin-Opener-Policy`, `Strict-Transport-Security`. Entry files (`index.html`, `main.dart.js`, `flutter_bootstrap.js`, `manifest.json`...) are `no-cache` because they are not content-hashed (otherwise users keep a stale build after a deploy); `assets/`, `canvaskit/` and `icons/` are cached for a day with background revalidation.

The CSP allows only your own origin plus `https://*.supabase.co` / `wss://*.supabase.co` and `https:` images. If you add an audio provider or CDN, extend `media-src` / `connect-src` in `tool/hosting.py`.

### Verify locally before deploying
```bash
python3 tool/serve_build.py 8080       # serves build/web with the production headers and deep-link fallback
```
Open `http://127.0.0.1:8080`, create a room, play a song, and check the browser console for CSP violations (there should be none; use `--no-csp` to compare).

## 5. Launch checklist
- [ ] Production Supabase project: anonymous sign-ins on, rate limits set, Realtime public access off, migrations applied, Advisors reviewed.
- [ ] `tool/live_security_check.mjs` passes against production.
- [ ] `purge_stale_rooms` scheduled.
- [ ] Built with the production config; headers verified; no external hosts besides Supabase in the browser network panel.
- [ ] Deep link test: open a `/room/<code>/guest` URL in a fresh private window (it should show the join page) and an unknown URL (should show "Page not found").
- [ ] Two real devices: DJ plays, a guest on another network sees the song, status and moving progress; close the DJ's tab and confirm guests see "DJ offline".
- [ ] Captcha decision made (see section 1.3).
- [ ] Error reporting hook set (`installGlobalErrorHandlers(report: ...)` in `lib/core/errors/error_reporting.dart`) if you use a crash reporting service.
- [ ] Backups: confirm the plan's database backup / point-in-time recovery policy; room data is ephemeral, but do not lose the schema.

## 6. Operations
- **Rollback:** static hosting keeps previous deploys; redeploy the previous `build/web`. Database migrations are forward-only: write a new corrective migration rather than editing an applied one, and keep migrations idempotent.
- **Capacity:** each open page holds two Realtime channels (data + presence). Check your Supabase plan's concurrent-connection, messages-per-second and channels-per-client limits; a room of N people produces N connections and every change fans out to N clients. Playback heartbeats are every 30 seconds per active DJ.
- **Costs to watch:** anonymous monthly active users, Realtime messages and connections, egress for `canvaskit.wasm` / `main.dart.js` (use a CDN in front of the host).
- **Known limitations:** guests see an informational, extrapolated progress bar, not sample-accurate sync; if the DJ's tab closes the room stays "playing" until guests' extrapolation window (45 s) ends; one DJ tab per room (a second tab shows a warning). Flutter Web renders to a canvas, so screen-reader support is limited compared with a DOM app.

## 7. Environment variables
| Name | Where | Notes |
|---|---|---|
| `SUPABASE_URL` | `env/<name>.json`, passed with `--dart-define-from-file` | project URL |
| `SUPABASE_PUBLISHABLE_KEY` | same | public key; safe in the browser; protected by RLS |

Nothing else is configured at build time. There are no server-side secrets in this repository.
