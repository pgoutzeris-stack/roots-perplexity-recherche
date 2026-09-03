#!/bin/bash
# Machine-readable setup steps, driven by the GUI installer.
#
#   engine.sh preflight   -> "MISSING: a b c" or "OK", plus "HAVECLI: 0|1"
#                            and "NODE: system|bundled|absent"
#   engine.sh nodeinstall -> unpacks Node.js into ~/.roots/node if needed
#   engine.sh conflicts   -> one conflicting plugin id per line, empty if none
#   engine.sh register    -> "RESULT: installed" or "RESULT: manual"
#   engine.sh haskey      -> exit 0 if a key file exists
#   engine.sh dest        -> prints the install destination
set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$(cd "$SELF_DIR/../../.." && pwd)"
DEST="$HOME/.roots/perplexity-recherche"
KEY_FILE="$HOME/.roots/perplexity-key"
PLUGIN_ID="roots-perplexity-recherche@roots-recherche"

# Findet die Claude-Code-Kommandozeile unabhaengig davon, wie dieses Skript
# gestartet wurde. Der Finder startet Apps mit einem minimalen PATH, in dem
# weder Homebrew noch ~/.local/bin noch nvm vorkommen. Deshalb wird zuerst die
# Login-Shell der Person gefragt, die kennt ihren echten PATH.
find_claude() {
  local c

  c="$(command -v claude 2>/dev/null)"
  if [ -n "$c" ] && [ -x "$c" ]; then echo "$c"; return 0; fi

  local shells="${SHELL:-} /bin/zsh /bin/bash"
  for sh in $shells; do
    [ -x "$sh" ] || continue
    c="$("$sh" -lc 'command -v claude' 2>/dev/null | tail -n 1)"
    if [ -n "$c" ] && [ -x "$c" ]; then echo "$c"; return 0; fi
  done

  # Bekannte Installationsorte, inklusive Versionsverzeichnisse der ueblichen
  # Node-Manager.
  local candidates="
    $HOME/.local/bin/claude
    $HOME/.claude/local/claude
    $HOME/bin/claude
    $HOME/.bun/bin/claude
    $HOME/.volta/bin/claude
    $HOME/.deno/bin/claude
    /opt/homebrew/bin/claude
    /usr/local/bin/claude
    /usr/bin/claude
  "
  for c in $candidates; do
    [ -x "$c" ] && { echo "$c"; return 0; }
  done

  for c in "$HOME"/.nvm/versions/node/*/bin/claude \
           "$HOME"/.fnm/node-versions/*/installation/bin/claude \
           "$HOME"/.asdf/installs/nodejs/*/bin/claude \
           "$HOME"/Library/pnpm/claude; do
    [ -x "$c" ] && { echo "$c"; return 0; }
  done

  # Globales npm-Praefix, falls npm erreichbar ist.
  local prefix
  prefix="$(npm prefix -g 2>/dev/null)"
  [ -n "$prefix" ] && [ -x "$prefix/bin/claude" ] && { echo "$prefix/bin/claude"; return 0; }

  return 1
}

is_installed() {
  python3 - <<'PY'
import json, os
p = os.path.expanduser("~/.claude/plugins/installed_plugins.json")
try:
    plugins = json.load(open(p)).get("plugins", {})
except Exception:
    plugins = {}
print("yes" if "roots-perplexity-recherche@roots-recherche" in plugins else "no")
PY
}

case "${1:-}" in
  preflight)
    MISSING=""
    # curl und python3 liegen bei macOS bei; node wird bei Bedarf mitgeliefert
    # und ist deshalb keine harte Voraussetzung.
    for c in curl python3; do
      command -v "$c" >/dev/null 2>&1 || MISSING="$MISSING $c"
    done
    CLAUDE_BIN="$(find_claude || true)"
    if [ -n "$CLAUDE_BIN" ]; then echo "HAVECLI: 1"; echo "CLAUDE: $CLAUDE_BIN"; else echo "HAVECLI: 0"; fi
    NODE_STATE="$(bash "$SELF_DIR/ensure-node.sh" --check 2>/dev/null)"
    [ -n "$NODE_STATE" ] || NODE_STATE="absent"
    echo "NODE: $NODE_STATE"
    if [ -n "$MISSING" ]; then echo "MISSING:$MISSING"; else echo "OK"; fi
    ;;

  nodeinstall)
    bash "$SELF_DIR/ensure-node.sh" --install
    ;;

  conflicts)
    [ -f "$HOME/.claude/plugins/installed_plugins.json" ] || exit 0
    python3 - <<'PY'
import json, os
p = os.path.expanduser("~/.claude/plugins/installed_plugins.json")
try:
    names = list(json.load(open(p)).get("plugins", {}))
except Exception:
    names = []
for n in names:
    if "perplexity" in n.lower() and not n.startswith("roots-perplexity-recherche@"):
        print(n)
PY
    ;;

  register)
    CLAUDE_BIN="$(find_claude || true)"
    if [ -z "$CLAUDE_BIN" ]; then echo "RESULT: no-cli"; exit 0; fi

    # Kommt die Einrichtung aus dem GitHub-Repo, wird der Marktplatz dort
    # registriert, dann holt Claude Updates selbst. Bei der Zip- und
    # App-Variante liegt der Marktplatz lokal, weil kein Netz vorausgesetzt
    # werden soll.
    if [ -n "${ROOTS_MARKETPLACE:-}" ]; then
      MARKET="$ROOTS_MARKETPLACE"
    else
      mkdir -p "$DEST"
      rm -rf "$DEST/.claude-plugin" "$DEST/plugins"
      cp -R "$SRC/.claude-plugin" "$SRC/plugins" "$DEST/" || { echo "RESULT: error"; exit 1; }
      chmod +x "$DEST"/plugins/roots-perplexity-recherche/scripts/*.sh
      MARKET="$DEST"
    fi
    "$CLAUDE_BIN" plugin marketplace add "$MARKET" >/dev/null 2>&1 || true
    if [ "$(is_installed)" = "no" ]; then
      "$CLAUDE_BIN" plugin install "$PLUGIN_ID" >/dev/null 2>&1 || true
    fi
    if [ "$(is_installed)" = "yes" ]; then echo "RESULT: installed"; else echo "RESULT: needs-tty"; fi
    ;;

  repair)
    # Oeffnet ein Terminal im Hintergrund, das die Registrierung mit echtem TTY
    # nachholt. Ohne "activate" bleibt das Fenster hinter dem Installer.
    RS="$SELF_DIR/repair.sh"
    rm -f "$HOME/.roots/repair.log"
    /usr/bin/osascript \
      -e 'on run argv' \
      -e 'tell application "Terminal" to do script ("bash " & quoted form of (item 1 of argv))' \
      -e 'end run' "$RS" >/dev/null 2>&1
    ;;

  findclaude)
    find_claude || { echo "" ; exit 1; }
    ;;

  haskey)  [ -f "$KEY_FILE" ] ;;
  dest)    echo "$DEST" ;;
  *)       echo "usage: engine.sh preflight|nodeinstall|conflicts|register|repair|findclaude|haskey|dest" >&2; exit 2 ;;
esac
