# CrowdDJ – Development Log

## Status
| Phase | State |
|---|---|
| 0 Inspection & planning | Done |
| 1 Foundation & UI | Done (landing page, theme, routing, design-system basics) |
| 2 Supabase backend | Done in code; migrations verified on local Postgres, NOT yet applied to a hosted project |
| 3 DJ & audience dashboards | Done (read-only live data; actions land in Phases 4–5) |
| 4 Queue & recommendations | Done |
| 5 Audio & realtime | Done and verified live |
| 6 Security & testing | Done; migration 5 applied and verified live (41/41) |
| 7 Production readiness | Done |

## Phase 0 – Analysis
- Starting point: untouched `flutter create` template (Flutter 3.47.0, Dart 3.13.0). No existing architecture or code was removed; the template `main.dart` was replaced and the counter test was rewritten.
- Platforms generated: android, ios, web.

## Architecture
Feature-first Clean Architecture; each feature has `data/` (models, data sources, repository impls), `domain/` (entities, repository interfaces, use cases) and `presentation/` (GetX controllers, bindings, screens, widgets).
GetX is used for state and DI only. Routing is `go_router` (URL is the source of truth for the room code, so deep links work). `BindingScope` (core/widgets) gives each go_router route a GetX Bindings lifecycle.

```
lib/core/{constants,theme,config,routes,utils,errors,network,services,widgets}
lib/features/{landing,room,dj_dashboard,audience,music_search,recommendations,queue,music_player}/{data,domain,presentation}
supabase/{migrations,functions}
```

## Dependencies
Added now: `get`, `go_router`, `flutter_web_plugins` (path URL strategy).
Added: `supabase_flutter` (Phase 2). Added when used: `dio` (Phase 4, music provider HTTP), `just_audio` (Phase 5).
Decision: no ScreenUtil; layouts are adaptive via `Breakpoints` (mobile <700, tablet <1100, desktop).
Font: Inter Tight, bundled as four static Latin subsets (weights 400/600/700/800, 38 KB each; SIL OFL licence in `assets/fonts/OFL.txt`; regenerate with `tool/subset_fonts.sh` from `tool/fonts/InterTight-variable.ttf`).

## Supabase requirements (Phase 2)
Project with Anonymous Sign-Ins enabled, Realtime enabled for `rooms`, `recommendations`, `queue`, `participants`. Env via `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_PUBLISHABLE_KEY=...` (publishable/anon key only; never the service role key). Without them the app shows a "Backend not configured" screen.

## Security strategy
- Anonymous auth; `participants.user_id = auth.uid()`, unique `(room_id, user_id)`.
- All writes go through `SECURITY DEFINER` RPCs with `set search_path = ''`, validating `auth.uid()`, membership and `rooms.host_user_id`; execute granted to `authenticated` only.
- RLS: read limited to room members; no direct client writes to `queue`, `rooms` playback fields, or recommendation status.
- Room codes from `gen_random_bytes` (not sequential); status/expiry checked in every RPC; per-participant recommendation rate limit in the RPC.
- Playback: `playback_version` guards against stale/duplicate "next" transitions.

## Music provider requirements
`MusicProvider` abstraction with a clearly labelled `MockMusicProvider` and licensed/royalty-free demo audio for the MVP. Spotify/YouTube do not grant unrestricted full-track playback to third-party web players, so they are out of scope unless used via their own licensed SDK/embed terms. Provider credentials live in Edge Functions, never in the client. just_audio on web requires CORS-enabled audio URLs, browser-supported codecs (MP3/AAC safest) and a user gesture before first play (autoplay policy).

## Hosting
`firebase.json` and `vercel.json` contain SPA rewrites so `/room/<code>` opens directly. Path URL strategy is enabled in `main.dart`.

## Phase 1 – Done
Theme (#0B0B12 / #151522, purple + electric blue), Inter Tight, routes (`/`, `/create-room`, `/room/:code`, `/room/:code/dj`, `/room/:code/guest`; the last four are placeholders), reusable widgets (`CrowdLogo`, `AppButton`, `AppCard`, `ContentContainer`), responsive landing page (hero, features, how it works, footer) and join-by-code/URL dialog (`LandingController`, `RoomCodeValidator`).
Verified: `flutter analyze` clean, `flutter test` 6 passing, `flutter build web` succeeds.

## Phase 2 – Done
Migrations in `supabase/migrations/` (apply in order):
1. `..._schema.sql` – tables, constraints, indexes per spec.
2. `..._rls.sql` – RLS on every table; members can only SELECT; no client INSERT/UPDATE/DELETE policies; realtime publication.
3. `..._rpc.sql` – SECURITY DEFINER RPCs (empty search_path, `auth.uid()` only, execute granted to `authenticated` only): `create_room`, `get_room_preview`, `join_room`, `touch_participant`, `recommend_song` (rate limited), `review_recommendation` (approve + enqueue atomically), `vote_recommendation`, `remove_queue_item`, `set_playback`, `play_next` (version-guarded against duplicate transitions), `close_room`.

Flutter: `Env`, `SupabaseSessionProvider` (reuses persisted anonymous session), room feature (entities, `RoomRepository`, RPC data source, `CreateRoom`/`JoinRoom`/`GetRoomPreview` use cases), Create Room screen, and `/room/:code` resolver (rejoins returning sessions, asks new guests for a name, redirects host→`/dj`, guest→`/guest`).

Verification (Phase 2): migrations applied to a throwaway local Postgres 16 with stubbed `auth`/roles; confirmed guest cannot approve or change playback, direct table writes are denied, duplicate `play_next` is rejected, closed rooms reject recommendations. `flutter analyze` clean, 17 tests pass, web build succeeds.
Not verified: behaviour against real Supabase (Anonymous Sign-Ins, Realtime), since no CrowdDJ project is connected yet. The only project visible to the MCP connection was an unrelated one and was left untouched.

### Setup
1. Create a Supabase project; enable Authentication → Sign In / Providers → Anonymous Sign-Ins.
2. Apply the three migrations (`supabase db push` or SQL editor, in order).
3. Copy `env/dev.example.json` to `env/dev.json` (git-ignored), fill it in, then `flutter run -d chrome --dart-define-from-file=env/dev.json`
4. Recommended: enable CAPTCHA/rate limits for anonymous sign-ins in Auth settings.

## Phase 3 – Done
- Domain/data: `Song`, `PlaybackState` (with `estimatedPositionMs`), `QueueItem`, `Recommendation`; read-only repositories over RLS-protected tables; `RoomRepository` gained `fetchRoom`/`fetchParticipants`.
- Controllers: `RoomController` (loads room + participants, role guard), `QueueController`, `RecommendationController`, `DJDashboardController`, `AudienceController`. Controllers are registered with a GetX tag per role+room (`roomTag`) so redirects between dashboards can't share/delete each other's instances.
- UI: DJ console (3-column desktop / 2-column tablet / tabbed mobile), audience view (2-column / tabbed mobile), now-playing card with local progress ticker, queue panel, pending-recommendations panel, "your recommendations" panel, participants panel, share-link strip with copy, loading skeletons, empty and error states.
- Route guard: `/room/:code/dj` and `/guest` redirect by actual role; non-members go to the join page. This is UX only; authorization is enforced by RLS/RPCs.
- Verified live against the CrowdDJ project: create room → DJ console; second origin opens the DJ URL → redirected to join → joined as guest → guest view; guest opening `/dj` is bounced to `/guest`; DJ view shows a recommendation seeded through the API.
- Bugs found and fixed during verification: malformed share URL (`...?#`); shared GetX registration causing the guest dashboard to hang after a `/dj` → `/guest` redirect.

Deliberately not wired yet (visible but disabled): Approve/Reject, Close room, transport controls (Phase 4/5). Guest song search + "Recommend" action arrive with the music-provider abstraction in Phase 4. The audience panel lists joined participants; live online presence arrives with Realtime in Phase 5. Data refreshes on load and via the refresh button until Realtime lands.
Not yet checked visually: DJ console at phone width (covered by a widget test only).

## Phase 4 – Done
- Music provider layer (`features/music_search`): `MusicProvider` (search / details / playable source), `SongSearchRepository`, `SongCandidate`, `PlayableSource`. `MockMusicProvider` is the only implementation: 12 entries, every title suffixed "(Demo)", no artwork, no audio (`getPlayableSource` returns null). The guest UI states it is sample data. Swap the single registration line in `AppServices` to change providers.
- Writes via RPCs only: `recommendSong`, `review` (approve enqueues atomically), `removeItem`, `closeRoom`.
- Guest: search (debounced, min 2 chars, stale responses dropped) → Recommend → "Sent" state; own recommendations show Pending/Approved/Rejected; search hidden when the DJ disables recommendations.
- DJ: Approve / Reject, remove from queue, Close room with confirmation; closed rooms show a closed view to everyone on next refresh.
- Feedback via snackbars (`NoticeListener`); backend error codes mapped to friendly messages.
- Verified live against the CrowdDJ project (host + guest on separate origins): approve → queue with attribution, reject, guest search + recommend → pending on DJ → close room → guest sees closed. `flutter analyze` clean; 50 tests pass.
- `dio` is still not added: no provider makes HTTP calls yet. Add it with the first real provider.

Open items: the 5 recommendation rate-limit and duplicate rules are enforced server-side but only the duplicate path has a UI message test. Voting UI (V2) not built. Data still refreshes manually until Phase 5 (Realtime).

## Phase 5 – Done
**Demo audio.** 12 original 24-second MP3s synthesised for this project (bass + arpeggio + drums generated by script, 56 kbps mono, ~2 MB total) in `assets/audio/demo-001..012.mp3`. They are ours, so there is no third-party licence, and they ship as same-origin assets, so there is no CORS. MP3 is supported by every major browser. `MockMusicProvider.getPlayableSource` returns these; the catalog durations are 24 s. Real providers must return only audio they are licensed to stream.

**Host-only playback.** `AudioPlaybackService` (load/play/pause/seek/stop/position/duration/state stream) with a `just_audio` implementation; only the DJ route creates one (`MusicPlayerController`). Web loads bundled audio by URL (just_audio_web cannot read `asset:///`), resolved through Flutter's asset manager so sub-path hosting works. Behaviour:
- Play from stopped → `play_next(expected_version)`; pause/resume/seek/restart → `set_playback`; skip → `play_next`; song end → `play_next` once (an `_advancing` flag plus the backend version guard reject duplicates).
- Publishes only at transitions plus a 30 s heartbeat while playing; guests extrapolate in between and stop extrapolating 45 s after the last heartbeat (`PlaybackState.staleAfter`).
- Autoplay: if the browser blocks `play()`, the DJ sees "press play", and guests are told "paused", not "playing". If audio fails to load after the backend advanced, the room is corrected to "paused".
- Host page reload: a room still marked "playing" is restored as "paused" at the estimated position until the DJ presses play.
- "Previous" restarts the current song (there is no play history).

**Realtime.** `RoomRealtime` / `SupabaseRoomRealtime`: a `postgres_changes` channel (rooms, participants, recommendations, queue; RLS applies) and a private presence channel `room:<id>`. Events are only hints: `RoomRealtimeController` coalesces them (200 ms) and re-reads authoritative state. After a connection drop it resyncs everything on reconnect, and the header shows RECONNECTING meanwhile. Subscriptions are removed on dispose. Presence drives the online count, per-participant online dots, and an "DJ offline" chip for guests.

**Migration 4** (applied to the CrowdDJ project and verified; `20261101000004_realtime_and_clock.sql`): Realtime authorization policies on `realtime.messages` (only room members can join or announce on `room:<id>`) and `server_time()` for clock-skew correction. **Apply it to the hosted project** (SQL editor) and, for enforcement, turn off "Allow public access" under Project Settings → Realtime. Until applied the app still works: presence is unavailable (counts fall back to joined participants) and the clock offset stays 0.

**Verified live** (CrowdDJ project, DJ and guest on separate origins): recommendations and participant joins appear on the DJ page without refresh; approve → queue; Play loads the MP3 (200, 169 KB), position advances; guest page shows the same song, Playing, moving progress with no interaction; Pause reaches the guest; song end auto-advances; the last song ending stops playback; closing the room reaches the guest live. 75 automated tests pass; `flutter analyze` clean.
**Presence and clock, verified live after migration 4:** `server_time()` returns 200 and matches the local clock; the audience panel switches to "Online now N" with green/grey dots; closing the DJ's tab shows the DJ and other guests as offline and the header count drops; a guest joining while the DJ is offline sees the red "DJ offline" chip. (Bug found: the audience screen never passed `hostOnline` / the server clock to the now-playing card; fixed and covered by a widget test.)
**Not verified live:** reconnect/resync after a real network drop (unit-tested with fakes), the autoplay-blocked path (unit-tested only), Safari/Firefox playback, DJ console at phone width, the host coming back online (covered by a widget test).
Testing tip: browsers cache `main.dart.js` aggressively; when checking a rebuild, serve it from a new port (new cache key) or hard-reload, otherwise you may be looking at the previous build.

**Bugs found while verifying (fixed):** queue and participants were returned in descending order (this Supabase client's `.order()` defaults to descending); `flutter clean` was required after adding `just_audio` because Flutter's cached web plugin registrant did not include it, so the plugin was silently unregistered (if audio ever fails with `MissingPluginException`, run `flutter clean`).

## Phase 6 – Security review and testing
Every RLS policy and every SECURITY DEFINER function was reviewed. Authorization (guests/strangers/anon vs host) held up; the review found these issues, fixed in `20261101000005_hardening.sql`:

| # | Finding | Severity | Fix |
|---|---|---|---|
| F1 | `songs` was one shared table filled with client-supplied metadata: the first writer of a provider id won, so a guest could plant a fake title or a tracking artwork URL that other rooms then displayed (reproduced locally). | High | Songs are per room (`unique(room_id, provider, provider_song_id)`), visible only to that room's members. Existing rows are split per room. |
| F2 | No bounds on song/name fields (`javascript:` and `http:` artwork URLs, huge titles, absurd durations). | Medium | Validation in the RPCs (friendly `invalid_song`) plus CHECK constraints as a backstop; artwork must be `https`. |
| F3 | No cap on room size or pending recommendations. | Medium | 300 participants per room (existing members can always rejoin); 200 pending per room, 10 per guest, 5 per guest per minute. |
| F4 | Control characters allowed in names. | Low | Rejected. |
| F5 | Lock order differed between `review_recommendation` and `recommend_song` (deadlock risk). | Low | Always room, then recommendation. |
| F6 | `set_playback` accepted any position. | Low | 0 to 24h. |
| F7 | Missing FK indexes; nothing ever deleted expired rooms. | Low | Indexes added; `purge_stale_rooms()` (not callable by clients) for pg_cron or an Edge Function. |
| C1 | Closing the room left the DJ's audio playing behind the "closed" screen. | Medium (UX) | `MusicPlayerController` stops audio and the heartbeat when the room closes. |
| C2 | The DJ console open in two tabs would play audio twice. | Low | Presence counts connections per participant; the DJ sees a warning. |

**Tests added**
- `supabase/tests/run_local.sh`: runs all migrations plus a 128-check SQL suite on a throwaway local Postgres (authorization per role, direct writes denied for host and guest, validation, per-room isolation, voting, rate limits, caps, expiry, closed rooms, anon role, internal functions not callable, Realtime topic policy, cleanup job). Against migrations 1-4 it fails 17 checks (the findings above); with migration 5 it passes all 128.
- `tool/live_security_check.mjs` (Node 22+): the same idea against the real project with four separate anonymous users, including a WebSocket probe that a room member can join the private presence channel and a stranger cannot. Run `node tool/live_security_check.mjs`; exit code 1 on any failure.
- Dart: 79 tests (provider, controllers, realtime, player, dashboards, role guards, multi-tab and DJ-offline UI).

**Live results after migration 5: 41 of 41 checks pass** (`node tool/live_security_check.mjs`), including the validation, per-room song isolation and position-bound checks that failed before. Before migration 5: all authorization checks passed (guests and strangers refused every host action; no direct writes for anyone; stale `play_next` rejected; closed rooms refuse writes; Realtime presence authorization works for members and refuses strangers). The only failures are the validation and per-room-song checks that migration 5 introduces.
A bug in my own first Realtime probe is worth remembering: without `presence.enabled: true` in the join config Realtime refuses *everyone*, so a "stranger refused" check passes for the wrong reason. The script now proves both sides.

**Residual risks / recommendations** (not code bugs)
- Anonymous sign-ups are unthrottled by the app: enable Authentication → Rate Limits and, before launch, captcha (needs a Turnstile/hCaptcha widget on the client).
- Room codes are 40-bit random; `get_room_preview` has no per-IP throttle. Acceptable for rooms that expire in 24 h; add API rate limiting (Supabase network/Edge) for public launch.
- Within a room, song metadata is still client-supplied (members can mislabel their own room's requests). Real providers should resolve metadata server-side in an Edge Function.
- Turn off "Allow public access" under Project Settings → Realtime, and run Advisors → Security / Performance in the dashboard after each migration.
- Schedule `select public.purge_stale_rooms();` (for example nightly with pg_cron). Orphaned anonymous users are not purged.
- `touch_participant` is currently unused by the client.

**Migration lesson:** the Supabase SQL editor does not keep session state between statements. A `TEMP` table (and `BEGIN`/`COMMIT`) in a migration therefore breaks it and can leave the database half-migrated. Migration 5 is written with no session state and every step is idempotent (`if not exists`, `create or replace`, one-statement CTEs); `supabase/tests/run_local.sh` re-applies the latest migration to keep it that way. Prefer `supabase db push` for real deployments.

## Phase 7 – Production readiness: Done
**Measured first** (browser, real load): the variable font was fetched once per declared weight (5 x 568 KB), and CanvasKit plus fallback fonts came from a Google CDN.

**Performance and robustness**
- Fonts: four static Latin subsets, 4 x 38 KB instead of 5 x 568 KB (about 2.7 MB less on first load).
- `--no-web-resources-cdn`: CanvasKit and fallback fonts are served from the app's own origin. A first load makes zero third-party requests; the only external host at runtime is Supabase.
- Sizes (release): `main.dart.js` 3.0 MB raw / 0.9 MB gzip; `canvaskit.wasm` 5.3 MB raw (compressed by the host); demo audio loads on demand.
- Unknown URLs show a "Page not found" page (go_router's default error page would have shown); global error hooks (`installGlobalErrorHandlers`, ready for a crash reporter); the landing animation is isolated in a `RepaintBoundary`.
- Real-text overflow fix: the DJ-name chip ellipsizes (it overflowed on 320-360 px phones with long names).

**Responsive verification:** `test/responsive_test.dart` lays out landing, create-room, DJ console and audience view at ten widths (320 to 1920 px) with long names and many rows, including every phone tab, using the real font (Flutter's default test font is about twice as wide and gives false overflows). Browser check at 375 px: DJ console renders correctly and plays audio. Not verified in the browser: tapping the small header icons in the emulated phone viewport (the browser tool's clicks did not register on them; the widget test confirms the close-room dialog opens at phone width).

**Production shell:** branded icons generated by `tool/generate_icons.py` (regular, maskable, apple-touch, favicon), manifest, theme colour, Open Graph tags, `robots.txt` (rooms disallowed), a CSS splash screen removed on first frame (no inline scripts, so no `unsafe-inline` for scripts).

**Hosting and security headers:** `tool/hosting.py` is the single source for `firebase.json`, `vercel.json`, `netlify.toml` and `docs/deploy/nginx.conf` (deep-link rewrites, CSP, nosniff, frame-ancestors, referrer, permissions, COOP, HSTS, cache policy: entry files `no-cache` because they are not content-hashed, assets cached). `tool/serve_build.py` serves a build with exactly those headers. Verified in a real browser under the full CSP: landing, create room (Supabase REST/auth), Realtime updates over WebSocket, approve, MP3 playback and close room all work with no CSP violations.

**Build and CI:** `tool/build_web.sh` validates the env file, refuses secret/service-role keys, builds with the production flags, scans the output for leaked secrets, and prints sizes. `.github/workflows/ci.yml` runs analyze, tests, a build, a hosting-config freshness check and the database suite (written but not executed by me: it has not run on GitHub).

**Docs:** `README.md`, `docs/DEPLOYMENT.md` (production Supabase settings, migrations via CLI, cleanup schedule, hosting, launch checklist, operations), `docs/MUSIC_PROVIDERS.md` (provider architecture and licensing rules).

**Final verification:** `flutter analyze` clean; 124 Dart tests pass; database suite 128/128; live security check 41/41 against the CrowdDJ project; production build succeeds with no secrets in the output.

## Remaining before a public launch (owner decisions, not code gaps)
- Create the separate production Supabase project and follow `docs/DEPLOYMENT.md` section 1 (rate limits, captcha decision, Realtime public access off, `purge_stale_rooms` schedule).
- Captcha needs a client-side widget (Turnstile/hCaptcha) before it can be enabled.
- Real music provider (Edge Function) if the product needs more than the demo catalog; see `docs/MUSIC_PROVIDERS.md`.
- Test on real devices and on Safari/Firefox; run the CI workflow once on GitHub.
- V2 features (voting UI, reactions, chat, moderation, analytics) are not built.
