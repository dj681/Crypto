#!/usr/bin/env bash
# Build script for Netlify.
# Installs Flutter (cached between builds), enables web, and produces build/web.
set -euo pipefail

FLUTTER_ROOT="${FLUTTER_ROOT:-/opt/build/cache/flutter}"

# ── 1. Install Flutter if not already cached ──────────────────────────────────
if [ ! -d "$FLUTTER_ROOT/bin" ]; then
  echo "Flutter not found at $FLUTTER_ROOT – installing…"
  git clone https://github.com/flutter/flutter.git -b stable --depth 1 "$FLUTTER_ROOT"
else
  echo "Using cached Flutter at $FLUTTER_ROOT"
fi

export PATH="$FLUTTER_ROOT/bin:$PATH"
flutter --version

# ── 2. Enable the web platform ────────────────────────────────────────────────
flutter config --enable-web
# Generate the web/ scaffold if it is not already present (it is not checked
# into this repo, so this ensures it exists before building).
flutter create . --platforms web

# ── 3. Install dependencies ───────────────────────────────────────────────────
flutter pub get

# ── 4. Build ──────────────────────────────────────────────────────────────────
# --base-href / → app is served at the Netlify site root.
flutter build web --release --web-renderer html --base-href / --dart-define=PWA_URL=https://mycryptosafe.fr/
