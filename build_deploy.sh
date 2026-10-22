#!/usr/bin/env bash
# Rebuild the Flutter web app and refresh the deploy/ folder that Vercel serves.
# Vercel has no Flutter SDK, so the built output is committed to Git.
set -euo pipefail
cd "$(dirname "$0")"
flutter build web --release
rm -rf deploy
cp -r build/web deploy
echo "deploy/ updated. Commit and push to redeploy on Vercel."
