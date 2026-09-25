#!/usr/bin/env bash
# pull 0xSero/omarchy-local-ai into this fork, keep our commits on top, redeploy the installed plugin
set -euo pipefail
cd "$(dirname "$0")"

INSTALL="$HOME/.config/omarchy/plugins/sero.local-ai"
KEEP=rtx-4050-laptop-6gb   # the card this fork carries on top of upstream

git fetch upstream

behind=$(git rev-list --count HEAD..upstream/main)
if [[ $behind == 0 ]]; then
  echo "local-ai: already at upstream ($(jq -r .version manifest.json))"
  exit 0
fi

echo "== $behind new upstream commits =="
git log --oneline HEAD..upstream/main

if ! git merge upstream/main --no-edit; then
  echo "merge stopped on conflicts — fix them, commit, then rerun $0" >&2
  exit 1
fi

# our card must still be in the recipes
jq -e --arg k "$KEEP" '.hardware[$k]' recipes.json >/dev/null \
  || { echo "$KEEP vanished from recipes.json — check the merge" >&2; exit 1; }

bash test/all

# redeploy what an install ships (the Makefile's RUNTIME list)
for f in manifest.json recipes.json local-ai.policy LICENSE Panel.qml Model.js lfm.svg qwen.svg hf.svg \
         bin/omarchy-local-ai bin/omarchy-install-ai-local bin/omarchy-remove-ai-local; do
  mkdir -p "$INSTALL/$(dirname "$f")"
  cp "$f" "$INSTALL/$f"
done
chmod +x "$INSTALL"/bin/*

echo "local-ai: updated to $(jq -r .version manifest.json) and redeployed to $INSTALL"
echo "restart the shell if Panel.qml or Model.js changed: omarchy shell restart"
