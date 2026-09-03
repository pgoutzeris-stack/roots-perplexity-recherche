#!/bin/bash
# Makes a usable node/npx available without touching the system or asking for a
# password. If neither is present, the official Node.js LTS build is unpacked
# into ~/.roots/node — user space only, checksum-verified, and invisible to any
# node the user may install later.
#
#   ensure-node.sh --check    prints system|bundled|absent, exits 0/0/1
#   ensure-node.sh --install  installs into ~/.roots/node if needed
#   ensure-node.sh --bindir   prints the directory holding node and npx
#
# Progress is written line by line to ~/.roots/node-install.log so a GUI can
# follow along.
set -uo pipefail

PREFIX="$HOME/.roots/node"
LOG="$HOME/.roots/node-install.log"
FALLBACK_VERSION="v22.20.0"

log() { mkdir -p "$(dirname "$LOG")"; printf '%s\n' "$*" >> "$LOG"; }

# Der Finder startet Apps mit einem minimalen PATH, in dem Homebrew, nvm und
# ~/.local/bin fehlen. Ein vorhandenes node wuerde sonst uebersehen und 200 MB
# unnoetig geladen. Deshalb wird zusaetzlich die Login-Shell gefragt.
system_npx_path() {
  local c
  c="$(command -v npx 2>/dev/null)"
  if [ -n "$c" ] && [ -x "$c" ]; then echo "$c"; return 0; fi
  local sh
  for sh in "${SHELL:-}" /bin/zsh /bin/bash; do
    [ -x "$sh" ] || continue
    c="$("$sh" -lc 'command -v npx' 2>/dev/null | tail -n 1)"
    if [ -n "$c" ] && [ -x "$c" ]; then echo "$c"; return 0; fi
  done
  return 1
}

have_system_node() {
  local npx_path
  npx_path="$(system_npx_path)" || return 1
  [ -x "$(dirname "$npx_path")/node" ]
}
have_bundled_node() {
  [ -x "$PREFIX/bin/node" ] && [ -x "$PREFIX/bin/npx" ]
}

state() {
  if have_system_node; then echo "system"
  elif have_bundled_node; then echo "bundled"
  else echo "absent"; fi
}

arch_tag() {
  case "$(uname -m)" in
    arm64)  echo "darwin-arm64" ;;
    x86_64) echo "darwin-x64" ;;
    *)      echo "" ;;
  esac
}

# Latest LTS from the official dist index, with a pinned fallback if offline or
# if the index format ever changes.
lts_version() {
  local v
  v="$(curl -fsS --max-time 20 https://nodejs.org/dist/index.json 2>/dev/null \
        | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(1)
for entry in data:
    if entry.get("lts"):
        print(entry["version"]); break
' 2>/dev/null)"
  case "$v" in
    v*) echo "$v" ;;
    *)  echo "$FALLBACK_VERSION" ;;
  esac
}

install_node() {
  local arch ver base tarball tmp
  arch="$(arch_tag)"
  if [ -z "$arch" ]; then
    log "FEHLER: nicht unterstuetzte Architektur $(uname -m)"
    return 1
  fi

  ver="$(lts_version)"
  tarball="node-$ver-$arch.tar.gz"
  base="https://nodejs.org/dist/$ver"

  log "Node.js $ver wird geladen"

  tmp="$(mktemp -d)" || return 1
  trap 'rm -rf "$tmp"' RETURN

  if ! curl -fsSL --max-time 600 -o "$tmp/$tarball" "$base/$tarball" 2>/dev/null; then
    log "FEHLER: Download fehlgeschlagen ($base/$tarball)"
    return 1
  fi
  if ! curl -fsSL --max-time 60 -o "$tmp/SHASUMS256.txt" "$base/SHASUMS256.txt" 2>/dev/null; then
    log "FEHLER: Pruefsummen nicht abrufbar"
    return 1
  fi

  log "Pruefsumme wird geprueft"
  if ! ( cd "$tmp" && grep " $tarball\$" SHASUMS256.txt | shasum -a 256 -c - >/dev/null 2>&1 ); then
    log "FEHLER: Pruefsumme stimmt nicht. Nichts installiert."
    return 1
  fi

  log "Wird entpackt"
  rm -rf "$PREFIX.new"
  mkdir -p "$PREFIX.new"
  if ! tar -xzf "$tmp/$tarball" -C "$PREFIX.new" --strip-components=1; then
    log "FEHLER: Entpacken fehlgeschlagen"
    rm -rf "$PREFIX.new"
    return 1
  fi

  if [ ! -x "$PREFIX.new/bin/node" ]; then
    log "FEHLER: node im Archiv nicht gefunden"
    rm -rf "$PREFIX.new"
    return 1
  fi
  if ! "$PREFIX.new/bin/node" -v >/dev/null 2>&1; then
    log "FEHLER: node laeuft auf diesem Rechner nicht"
    rm -rf "$PREFIX.new"
    return 1
  fi

  rm -rf "$PREFIX"
  mv "$PREFIX.new" "$PREFIX"
  log "FERTIG: Node.js $("$PREFIX/bin/node" -v) in $PREFIX"
  return 0
}

case "${1:-}" in
  --check)
    s="$(state)"; echo "$s"
    [ "$s" = "absent" ] && exit 1 || exit 0
    ;;
  --bindir)
    if have_system_node; then dirname "$(system_npx_path)"
    elif have_bundled_node; then echo "$PREFIX/bin"
    else exit 1; fi
    ;;
  --install)
    rm -f "$LOG"
    s="$(state)"
    if [ "$s" != "absent" ]; then log "FERTIG: bereits vorhanden ($s)"; exit 0; fi
    install_node || exit 1
    ;;
  *)
    echo "usage: ensure-node.sh --check|--install|--bindir" >&2; exit 2 ;;
esac
