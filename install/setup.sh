#!/bin/bash
# ROOTS Perplexity-Recherche — Einrichtung direkt aus GitHub.
#
#   curl -fsSL https://raw.githubusercontent.com/pgoutzeris-stack/roots-perplexity-recherche/main/install/setup.sh | bash
#
# Laedt den aktuellen Stand des Repos und startet den gefuehrten Ablauf.
# Skripte, die ausdruecklich an bash uebergeben werden, unterliegen Gatekeeper
# nicht, deshalb gibt es auf diesem Weg keine Signaturwarnung.
set -uo pipefail

REPO="pgoutzeris-stack/roots-perplexity-recherche"
BRANCH="${ROOTS_BRANCH:-main}"

die() { echo "Abbruch: $1" >&2; exit 1; }

command -v curl >/dev/null 2>&1 || die "curl fehlt"
command -v tar  >/dev/null 2>&1 || die "tar fehlt"

TMP="$(mktemp -d)" || die "kein temporaeres Verzeichnis"
trap 'rm -rf "$TMP"' EXIT

echo "Lade den aktuellen Stand aus $REPO ..."
if ! curl -fsSL --max-time 120 \
     "https://codeload.github.com/$REPO/tar.gz/refs/heads/$BRANCH" \
     -o "$TMP/src.tgz"; then
  die "Repo nicht erreichbar. Netz pruefen, oder Zweig $BRANCH existiert nicht."
fi

tar xz -C "$TMP" -f "$TMP/src.tgz" || die "Archiv beschaedigt"

SRC="$(find "$TMP" -maxdepth 1 -type d -name '*roots-perplexity-recherche*' | head -n 1)"
[ -n "$SRC" ] || die "Archivinhalt unerwartet"
[ -f "$SRC/install/install.sh" ] || die "Installer im Archiv nicht gefunden"

chmod +x "$SRC"/plugins/roots-perplexity-recherche/scripts/*.sh 2>/dev/null || true

# Der Marktplatz wird auf das Repo gesetzt, nicht auf eine lokale Kopie: dann
# holt Claude spaetere Versionen selbst.
export ROOTS_MARKETPLACE="$REPO"
exec bash "$SRC/install/install.sh"
