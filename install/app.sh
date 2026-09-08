#!/bin/bash
# Holt den Installer auf den Rechner und startet ihn.
#
#   curl -fsSL https://raw.githubusercontent.com/pgoutzeris-stack/roots-perplexity-recherche/main/install/app.sh | bash
#
# Warum das ohne Gatekeeper-Warnung laeuft: das Kennzeichen
# com.apple.quarantine setzt nur, wer es anfordert — Browser, Mail, Slack,
# Teams. curl fordert es nicht an. Eine so geholte App startet deshalb per
# Doppelklick ohne Signaturdialog, obwohl sie unsigniert ist.
set -uo pipefail

REPO="pgoutzeris-stack/roots-perplexity-recherche"
ASSET="ROOTS-Perplexity-Installer.zip"
APPNAME="ROOTS Perplexity installieren.app"
DEST="$HOME/Applications"

die() { echo "Abbruch: $1" >&2; exit 1; }

command -v curl >/dev/null 2>&1 || die "curl fehlt"
command -v ditto >/dev/null 2>&1 || die "ditto fehlt"

TMP="$(mktemp -d)" || die "kein temporaeres Verzeichnis"
trap 'rm -rf "$TMP"' EXIT

echo "Lade den Installer ..."
URL="https://github.com/$REPO/releases/latest/download/$ASSET"
if ! curl -fsSL --max-time 300 "$URL" -o "$TMP/app.zip"; then
  die "Installer nicht abrufbar. Netz pruefen, oder es gibt noch keine Veroeffentlichung."
fi

mkdir -p "$DEST"
rm -rf "$DEST/$APPNAME"
ditto -xk "$TMP/app.zip" "$TMP/out" || die "Archiv beschaedigt"
[ -d "$TMP/out/$APPNAME" ] || die "Archivinhalt unerwartet"
mv "$TMP/out/$APPNAME" "$DEST/" || die "Kopieren nach $DEST fehlgeschlagen"

# Sicherheitsnetz: falls doch ein Kennzeichen mitkam, hier entfernen.
xattr -dr com.apple.quarantine "$DEST/$APPNAME" 2>/dev/null || true

if xattr "$DEST/$APPNAME" 2>/dev/null | grep -q quarantine; then
  echo "Hinweis: das Download-Kennzeichen liess sich nicht entfernen."
  echo "Die App liegt in $DEST und braucht einmal Rechtsklick, Oeffnen."
else
  echo "Installer liegt in $DEST"
fi

echo "Wird gestartet ..."
open "$DEST/$APPNAME" || die "Start fehlgeschlagen, App liegt in $DEST"
