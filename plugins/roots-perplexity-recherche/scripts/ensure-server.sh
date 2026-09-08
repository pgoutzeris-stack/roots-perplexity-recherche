#!/bin/bash
# Installs the Perplexity MCP server once into ~/.roots/mcp so Claude can start
# it directly. Without this, every start goes through npx, which re-resolves the
# package: rund 0,75 s warm und 3,6 s mit kaltem Cache, jedes Mal.
#
#   ensure-server.sh --check    prints local|npx|absent
#   ensure-server.sh --install  installs into ~/.roots/mcp
#   ensure-server.sh --bin      prints the server executable
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PREFIX="$HOME/.roots/mcp"
BIN="$PREFIX/node_modules/.bin/perplexity-mcp"
PKG="@perplexity-ai/mcp-server"
PINNED="1.2.1"
LOG="$HOME/.roots/server-install.log"

log() { mkdir -p "$(dirname "$LOG")"; printf '%s\n' "$*" >> "$LOG"; }

npm_bin() {
  local dir
  dir="$(bash "$HERE/ensure-node.sh" --bindir 2>/dev/null)" || return 1
  [ -x "$dir/npm" ] && { echo "$dir/npm"; return 0; }
  command -v npm 2>/dev/null
}

case "${1:-}" in
  --check)
    if [ -x "$BIN" ]; then echo local
    elif bash "$HERE/ensure-node.sh" --check >/dev/null 2>&1; then echo npx
    else echo absent; fi
    ;;

  --bin)
    [ -x "$BIN" ] && { echo "$BIN"; exit 0; }
    exit 1
    ;;

  --install)
    rm -f "$LOG"
    if [ -x "$BIN" ]; then
      log "FERTIG: bereits installiert ($("$BIN" --version 2>/dev/null || echo "$PINNED"))"
      exit 0
    fi
    NPM="$(npm_bin)" || { log "FEHLER: npm nicht gefunden"; exit 1; }
    NODE_DIR="$(bash "$HERE/ensure-node.sh" --bindir 2>/dev/null || true)"
    [ -n "$NODE_DIR" ] && PATH="$NODE_DIR:$PATH" && export PATH

    log "Recherche-Server $PKG@$PINNED wird installiert"
    mkdir -p "$PREFIX"
    if ! "$NPM" install --prefix "$PREFIX" --no-audit --no-fund --loglevel=error \
         "$PKG@$PINNED" >>"$LOG" 2>&1; then
      log "Feste Version nicht verfuegbar, versuche die aktuelle"
      if ! "$NPM" install --prefix "$PREFIX" --no-audit --no-fund --loglevel=error \
           "$PKG" >>"$LOG" 2>&1; then
        log "FEHLER: Installation fehlgeschlagen"
        exit 1
      fi
    fi
    [ -x "$BIN" ] || { log "FEHLER: Startprogramm fehlt nach der Installation"; exit 1; }
    log "FERTIG: Recherche-Server in $PREFIX"
    ;;

  *) echo "usage: ensure-server.sh --check|--install|--bin" >&2; exit 2 ;;
esac
