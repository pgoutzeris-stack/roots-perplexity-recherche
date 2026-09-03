#!/bin/bash
# Registers the plugin from a real terminal with a TTY. The Claude Code CLI
# waits for input on some setups, which a GUI-launched shell cannot provide.
# Progress is written to ~/.roots/repair.log so the installer can follow along.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="$HOME/.roots/perplexity-recherche"
PLUGIN_ID="roots-perplexity-recherche@roots-recherche"
LOG="$HOME/.roots/repair.log"

mkdir -p "$(dirname "$LOG")"
: > "$LOG"
log() { printf '%s\n' "$*" | tee -a "$LOG"; }

echo "════════════════════════════════════════════════"
echo "  ROOTS Perplexity — Registrierung"
echo "════════════════════════════════════════════════"
echo

CLAUDE_BIN="$(bash "$HERE/engine.sh" findclaude 2>/dev/null)"
if [ -z "$CLAUDE_BIN" ]; then
  log "FEHLER: Claude Code wurde auf diesem Rechner nicht gefunden."
  echo
  echo "Claude Code installieren, dann den Installer erneut starten."
  echo "Fenster kann geschlossen werden."
  exit 1
fi
log "Claude Code: $CLAUDE_BIN"

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

log "Marktplatz wird registriert"
"$CLAUDE_BIN" plugin marketplace add "$DEST" 2>&1 | sed 's/^/    /' || true

if [ "$(is_installed)" = "yes" ]; then
  log "Plugin war bereits installiert"
else
  log "Plugin wird installiert"
  "$CLAUDE_BIN" plugin install "$PLUGIN_ID" 2>&1 | sed 's/^/    /' || true
fi

if [ "$(is_installed)" = "yes" ]; then
  log "FERTIG: Plugin registriert"
  echo
  echo "Claude mit Cmd+Q beenden und neu starten. Fenster kann geschlossen werden."
  exit 0
fi

log "FEHLER: Registrierung nicht bestaetigt"
echo
echo "Von Hand in Claude Code:"
echo "    /plugin marketplace add $DEST"
echo "    /plugin install $PLUGIN_ID"
echo
echo "Fenster kann geschlossen werden."
exit 1
