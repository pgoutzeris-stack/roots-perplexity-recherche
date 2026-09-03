#!/bin/bash
# Quits and reopens the Claude desktop app so a freshly registered plugin is
# loaded. Progress goes to ~/.roots/restart.log for the installer to follow.
#
# Deliberately does NOT kill "claude" processes: a Claude Code session in a
# terminal or inside the app may belong to work in progress, and pattern-killing
# by process name would take the caller's own session down with it.
set -uo pipefail

BUNDLE="com.anthropic.claudefordesktop"
LOG="$HOME/.roots/restart.log"

mkdir -p "$(dirname "$LOG")"
: > "$LOG"
log() { printf '%s\n' "$*" >> "$LOG"; }

find_app() {
  local p
  for p in /Applications/Claude.app "$HOME/Applications/Claude.app"; do
    [ -d "$p" ] && { echo "$p"; return 0; }
  done
  p="$(mdfind "kMDItemCFBundleIdentifier == '$BUNDLE'" 2>/dev/null | head -n 1)"
  [ -n "$p" ] && [ -d "$p" ] && { echo "$p"; return 0; }
  return 1
}

APP="$(find_app || true)"
if [ -z "$APP" ]; then
  log "FEHLER: Die Claude-App wurde auf diesem Rechner nicht gefunden."
  exit 1
fi
log "App gefunden"

is_running() {
  /usr/bin/osascript -e "application id \"$BUNDLE\" is running" 2>/dev/null | grep -q true
}

if is_running; then
  log "Claude wird beendet"
  /usr/bin/osascript -e "tell application id \"$BUNDLE\" to quit" >/dev/null 2>&1 || true

  i=0
  while [ "$i" -lt 25 ]; do
    is_running || break
    sleep 1
    i=$((i + 1))
  done

  if is_running; then
    log "FEHLER: Claude liess sich nicht beenden. Bitte von Hand mit Cmd+Q."
    exit 1
  fi
  log "Beendet"
else
  log "Claude lief nicht"
fi

sleep 1
log "Claude wird gestartet"
if ! /usr/bin/open -b "$BUNDLE" >/dev/null 2>&1; then
  /usr/bin/open -a "$APP" >/dev/null 2>&1 || { log "FEHLER: Start fehlgeschlagen."; exit 1; }
fi

i=0
while [ "$i" -lt 30 ]; do
  is_running && { log "FERTIG: Claude läuft wieder"; exit 0; }
  sleep 1
  i=$((i + 1))
done

log "FEHLER: Claude ist nicht wieder gestartet. Bitte von Hand oeffnen."
exit 1
