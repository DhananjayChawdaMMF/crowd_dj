#!/usr/bin/env bash
# Production web build with safety checks.
#
#   tool/build_web.sh [env-file] [--base-href /sub/path/] [--check]
#
#   env-file     JSON with SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY (default env/prod.json)
#   --base-href  only when serving from a sub-path (must start and end with /)
#   --check      run `flutter analyze` and `flutter test` first
set -euo pipefail
cd "$(dirname "$0")/.."

ENV_FILE="env/prod.json"; BASE_HREF=""; CHECK=0
while [ $# -gt 0 ]; do
  case "$1" in
    --base-href) BASE_HREF="$2"; shift 2 ;;
    --check) CHECK=1; shift ;;
    -*) echo "unknown option $1" >&2; exit 2 ;;
    *) ENV_FILE="$1"; shift ;;
  esac
done

[ -f "$ENV_FILE" ] || { echo "Missing $ENV_FILE. Copy env/prod.example.json and fill it in." >&2; exit 1; }

# Validate the config and refuse secret keys: only the PUBLIC publishable/anon key may ship.
python3 - "$ENV_FILE" <<'PY'
import base64, json, sys
cfg = json.load(open(sys.argv[1]))
url, key = cfg.get("SUPABASE_URL", ""), cfg.get("SUPABASE_PUBLISHABLE_KEY", "")
errors = []
if not url.startswith("https://") or "<" in url: errors.append("SUPABASE_URL must be your https project URL")
if not key or "<" in key: errors.append("SUPABASE_PUBLISHABLE_KEY is missing")
if key.startswith("sb_secret_"): errors.append("that is a SECRET key; use the publishable key")
if key.count(".") == 2:  # legacy JWT keys
    try:
        payload = json.loads(base64.urlsafe_b64decode(key.split(".")[1] + "=" * 3))
        if payload.get("role") != "anon": errors.append(f"JWT role is '{payload.get('role')}', must be 'anon' (never ship service_role)")
    except Exception: errors.append("key looks like a JWT but cannot be decoded")
if errors:
    print("Refusing to build:\n  - " + "\n  - ".join(errors), file=sys.stderr); sys.exit(1)
print(f"config ok: {url}")
PY

if [ "$CHECK" = 1 ]; then
  flutter analyze
  flutter test
fi

flutter pub get >/dev/null
ARGS=(build web --release --no-web-resources-cdn "--dart-define-from-file=$ENV_FILE")
[ -n "$BASE_HREF" ] && ARGS+=("--base-href" "$BASE_HREF")
flutter "${ARGS[@]}"

# Post-build checks.
[ -f build/web/index.html ] || { echo "build/web/index.html missing" >&2; exit 1; }
# Look for real secrets in the output (the Supabase library itself mentions the
# words "service_role"/"sb_secret_", so match actual key shapes, not words).
python3 - <<'PY'
import base64, pathlib, re, sys
bad = []
for f in pathlib.Path("build/web").rglob("*"):
    if f.suffix not in {".js", ".json", ".html"} or not f.is_file():
        continue
    text = f.read_text(errors="ignore")
    if re.search(r"sb_secret_[A-Za-z0-9_-]{20,}", text):
        bad.append(f"{f}: secret key")
    for m in re.finditer(r"eyJ[A-Za-z0-9_-]{10,}\.([A-Za-z0-9_-]{10,})\.[A-Za-z0-9_-]{10,}", text):
        try:
            payload = base64.urlsafe_b64decode(m.group(1) + "=" * 3).decode(errors="ignore")
        except Exception:
            continue
        if "service_role" in payload:
            bad.append(f"{f}: service_role JWT")
if bad:
    print("A secret key leaked into the build output:\n  " + "\n  ".join(bad), file=sys.stderr)
    sys.exit(1)
print("no secret keys in build output")
PY
echo; echo "Build size:"
for f in build/web/main.dart.js build/web/flutter_bootstrap.js; do
  printf "  %-32s %8s KB raw  %8s KB gzip\n" "$f" "$(( $(wc -c < "$f") / 1024 ))" "$(( $(gzip -9 -c "$f" | wc -c) / 1024 ))"
done
echo "  total build/web: $(du -sh build/web | cut -f1)  (canvaskit is only fetched on demand)"
echo; echo "Done. Deploy build/web (see docs/DEPLOYMENT.md)."
