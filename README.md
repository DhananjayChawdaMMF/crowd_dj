# CrowdDJ

A collaborative music room for the web. A DJ creates a room and shares a link; anyone with the link joins as a guest (no account), recommends songs, and watches the queue and playback live. Only the DJ's browser plays audio.

Built with Flutter Web, GetX, `go_router` and Supabase (Postgres, Realtime, anonymous auth, RLS).

## Features
- Create a room, share `/room/<code>`; deep links work in a fresh tab.
- Guests join anonymously with a display name; the DJ approves or rejects recommendations.
- Host-only audio (`just_audio`); guests see the song, status and a live progress bar.
- Live updates: recommendations, queue, playback, presence ("online now", "DJ offline").
- Authorization enforced in the database (RLS + `SECURITY DEFINER` functions), not just in the UI.
- Responsive: phone (tabbed), tablet, desktop (three columns).

## Quick start
Prerequisites: Flutter (stable, Dart 3.13+), a Supabase project, Node 22+ and Python 3 for the tools.

1. Create a Supabase project. Enable **Authentication, Sign In / Providers, Anonymous Sign-Ins**.
2. Apply the migrations in `supabase/migrations/` in order (`supabase db push`, or paste `supabase/setup.sql` into the SQL editor of a *fresh* project).
3. `cp env/dev.example.json env/dev.json` and fill in your project URL and **publishable** key (never a secret/service-role key).
4. Run:
   ```bash
   flutter run -d chrome --dart-define-from-file=env/dev.json
   ```

## Tests
```bash
flutter analyze && flutter test                  # Dart: unit, controller and widget tests
supabase/tests/run_local.sh                      # 128-check database security suite (needs local PostgreSQL)
node tool/live_security_check.mjs                # live multi-session security check against env/dev.json
```

## Deploy
```bash
tool/build_web.sh env/prod.json                  # validated production build into build/web
```
See [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) for Supabase production settings, hosting (Firebase, Vercel, Netlify, nginx), security headers and a launch checklist.

## Project layout
```
lib/core/            theme, routing, errors, services, shared widgets
lib/features/<f>/    data/ (models, data sources, repo impls)  domain/ (entities, interfaces, use cases)  presentation/ (GetX controllers, bindings, screens)
supabase/migrations/ schema, RLS, RPCs, realtime auth, hardening
supabase/tests/      local database test harness and security suite
tool/                build, hosting config generator, icons, fonts, live security check
docs/                deployment guide, music provider guide
```
Features: `landing`, `room`, `dj_dashboard`, `audience`, `music_search`, `recommendations`, `queue`, `music_player`.

## Documentation
- [DEVELOPMENT.md](DEVELOPMENT.md): phase-by-phase log, decisions, findings and verification notes.
- [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md): production setup and operations.
- [docs/MUSIC_PROVIDERS.md](docs/MUSIC_PROVIDERS.md): music source architecture and licensing rules.

## Licenses
Application code: see your project's licence. Inter Tight font: SIL Open Font License 1.1 (`assets/fonts/OFL.txt`). Demo audio in `assets/audio` was synthesised for this project.
