#!/bin/bash
# Guided setup for the ROOTS Perplexity research plugin. Walks through every
# step: prerequisites, API key, plugin registration, verification.
set -uo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="$HOME/.roots/perplexity-recherche"
KEY_FILE="$HOME/.roots/perplexity-key"
PLUGIN_ID="roots-perplexity-recherche@roots-recherche"

STEPS=6
step() { echo; echo "── $1/$STEPS  $2"; echo; }
die()  { echo; echo "Abbruch: $1" >&2; exit 1; }
ask()  { printf '%s [j/N] ' "$1"; IFS= read -r a; case "$a" in [jJyY]*) return 0;; *) return 1;; esac; }

cat <<'HEAD'
════════════════════════════════════════════════════════════════
  ROOTS Perplexity-Recherche — Einrichtung
════════════════════════════════════════════════════════════════

Was passiert:
  1. Voraussetzungen pruefen
  2. Konflikte mit anderen Perplexity-Plugins pruefen
  3. Eigenen API-Key anlegen und hinterlegen
  4. Plugin bei Claude Code registrieren
  5. Einrichtung verifizieren
  6. Zusammenfassung

Der API-Key bleibt auf diesem Rechner, in ~/.roots/perplexity-key mit
Rechten 600. Er wird bei der Eingabe nicht angezeigt und landet weder in
der Claude-Konfiguration noch in einem Chat.

Kosten laufen ueber dein eigenes Perplexity-Konto.
HEAD

ask "Weiter?" || die "auf Wunsch beendet"

# ── 1 ─────────────────────────────────────────────────────────
step 1 "Voraussetzungen"

MISSING=""
for c in curl python3; do
  if command -v "$c" >/dev/null 2>&1; then printf '  %-12s ok\n' "$c"
  else printf '  %-12s FEHLT\n' "$c"; MISSING="$MISSING $c"; fi
done

NODE_SH="$SRC/plugins/roots-perplexity-recherche/scripts/ensure-node.sh"
NODE_STATE="$(bash "$NODE_SH" --check 2>/dev/null)"
[ -n "$NODE_STATE" ] || NODE_STATE="absent"
case "$NODE_STATE" in
  system)  printf '  %-12s ok (%s, systemweit)\n' "node" "$(node -v 2>/dev/null)" ;;
  bundled) printf '  %-12s ok (%s, in ~/.roots/node)\n' "node" "$("$HOME/.roots/node/bin/node" -v 2>/dev/null)" ;;
  absent)
    printf '  %-12s wird eingerichtet ...\n' "node"
    echo "               Node.js wird nach ~/.roots/node entpackt, etwa 50 MB."
    echo "               Kein Passwort, keine Systemaenderung."
    if bash "$NODE_SH" --install; then
      printf '  %-12s ok (%s, in ~/.roots/node)\n' "node" "$("$HOME/.roots/node/bin/node" -v 2>/dev/null)"
    else
      echo "  node         FEHLGESCHLAGEN — siehe ~/.roots/node-install.log"
      echo "               Alternative: https://nodejs.org (LTS) installieren."
      MISSING="$MISSING node"
    fi ;;
esac

if command -v claude >/dev/null 2>&1; then
  echo "  claude CLI   ok"
  HAVE_CLI=1
else
  echo "  claude CLI   nicht gefunden — Plugin wird spaeter manuell registriert"
  HAVE_CLI=0
fi

[ -n "$MISSING" ] && die "fehlende Voraussetzungen:$MISSING"

# ── 2 ─────────────────────────────────────────────────────────
step 2 "Konflikte pruefen"

CONFLICT=0
if [ -f "$HOME/.claude/plugins/installed_plugins.json" ]; then
  OTHER=$(python3 - <<'PY'
import json, os
p = os.path.expanduser("~/.claude/plugins/installed_plugins.json")
try:
    names = list(json.load(open(p)).get("plugins", {}))
except Exception:
    names = []
hits = [n for n in names if "perplexity" in n.lower() and not n.startswith("roots-perplexity-recherche@")]
print("\n".join(hits))
PY
)
  if [ -n "$OTHER" ]; then
    CONFLICT=1
    echo "  Bereits installiert:"
    printf '    %s\n' $OTHER
    echo
    echo "  Zwei Perplexity-Plugins gleichzeitig liefern zwei Saetze gleich"
    echo "  benannter Werkzeuge. Claude waehlt dann unvorhersehbar, und die"
    echo "  Kosten verteilen sich auf zwei Konten."
    echo
    echo "  Empfehlung: das andere vorher mit  /plugin uninstall  entfernen."
    ask "  Trotzdem fortfahren?" || die "erst das andere Plugin entfernen"
  fi
fi
[ "$CONFLICT" -eq 0 ] && echo "  Keine Konflikte."

# ── 3 ─────────────────────────────────────────────────────────
step 3 "API-Key"

if [ -f "$KEY_FILE" ]; then
  echo "  Es liegt schon ein Key in $KEY_FILE"
  # Vorauswahl ist Behalten: ein versehentliches Enter darf keinen
  # funktionierenden Key loeschen.
  if ask "  Einen neuen Key eintragen und den bestehenden ersetzen?"; then
    rm -f "$KEY_FILE"
  else
    echo "  Bestehender Key bleibt."
  fi
fi

if [ ! -f "$KEY_FILE" ]; then
  echo "  Vier Schritte in der Perplexity-Konsole:"
  echo
  echo "    1  Anmelden oder Konto anlegen"
  echo "       https://www.perplexity.ai/settings/api"
  echo
  echo "    2  Key erzeugen"
  echo "       Menue \"API Keys\" -> Generate"
  echo "       Beginnt mit pplx- und wird nur einmal angezeigt. Sofort kopieren."
  echo
  echo "    3  Guthaben aufladen"
  echo "       Menue \"Billing\" -> Add credits -> 5 Dollar"
  echo "       Eine Suche kostet rund 1 Cent, eine Nachfrage wenige Cent."
  echo "       5 Dollar reichen fuer einige hundert Suchen."
  echo
  echo "    4  Monatliches Limit setzen"
  echo "       Menue \"Billing\" -> Monthly spend limit -> 20 Dollar"
  echo "       Ein Deep-Research-Call kostet 50 Cent bis 2 Dollar."
  echo "       Ohne Limit gibt es keine Obergrenze."
  echo
  if ask "  Konsole jetzt im Browser oeffnen?"; then
    open "https://www.perplexity.ai/settings/api" 2>/dev/null || true
    echo "  Geoeffnet. Key kopieren, dann hier weiter."
    printf '  Enter, wenn der Key in der Zwischenablage liegt: '; IFS= read -r _
  fi
  echo
  bash "$SRC/plugins/roots-perplexity-recherche/scripts/set-key.sh" \
    || die "Key wurde nicht hinterlegt"
fi

# ── 4 ─────────────────────────────────────────────────────────
step 4 "Plugin registrieren"

# Kommt die Einrichtung aus dem GitHub-Repo, wird der Marktplatz dort
# registriert, dann holt Claude spaetere Versionen selbst. Bei der Zip- und
# App-Variante liegt der Marktplatz lokal, weil kein Netz vorausgesetzt wird.
if [ -n "${ROOTS_MARKETPLACE:-}" ]; then
  MARKET="$ROOTS_MARKETPLACE"
  echo "  Marktplatz: $MARKET"
else
  MARKET="$DEST"
  echo "  Kopiere das Paket nach $DEST"
  mkdir -p "$DEST"
  rm -rf "$DEST/.claude-plugin" "$DEST/plugins"
  cp -R "$SRC/.claude-plugin" "$SRC/plugins" "$DEST/" || die "Kopieren fehlgeschlagen"
  chmod +x "$DEST"/plugins/roots-perplexity-recherche/scripts/*.sh
fi

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

INSTALLED=no
if [ "$HAVE_CLI" -eq 1 ]; then
  claude plugin marketplace add "$MARKET" 2>&1 | sed 's/^/    /' || true
  if [ "$(is_installed)" = "yes" ]; then
    echo "    Plugin schon installiert, uebersprungen."
  else
    claude plugin install "$PLUGIN_ID" 2>&1 | sed 's/^/    /' || true
  fi
  INSTALLED="$(is_installed)"
fi

if [ "$INSTALLED" = "yes" ]; then
  echo "  Registriert."
else
  echo "  Konnte nicht automatisch installiert werden."
  echo "  In Claude Code eintippen:"
  echo "      /plugin marketplace add $MARKET"
  echo "      /plugin install $PLUGIN_ID"
fi

# ── 5 ─────────────────────────────────────────────────────────
step 5 "Verifikation"
bash "$DEST/plugins/roots-perplexity-recherche/scripts/check.sh" 2>&1 | sed 's/^/  /'
CHECK=${PIPESTATUS[0]}

# ── 6 ─────────────────────────────────────────────────────────
step 6 "Zusammenfassung"

if [ "$CHECK" -eq 0 ] && [ "$INSTALLED" = "yes" ]; then
  cat <<'DONE'
  Fertig. Ein Schritt bleibt von Hand:

      Claude komplett beenden (Cmd+Q) und neu starten.

  Erst danach startet der MCP-Server und liest den Key.

  Danach verfuegbar:
      perplexity_search    Quellen sammeln, guenstigster Call
      perplexity_ask       eine Zahl oder ein Fakt, gegengeprueft
      perplexity_research  nur fuer bewusst weite Fragen, teuer

  Der Skill triggert von allein, sobald du nach externen Fakten fragst.
  Er fragt zuerst sieben Leitplanken ab und legt einen Query-Plan zur
  Freigabe vor. Erst nach deinem Ja fliesst Geld.

  Jederzeit pruefen:   /perplexity-status
  Key erneuern:        /perplexity-key
DONE
else
  echo "  Nicht vollstaendig. Offene Punkte siehe Schritt 5 und 4."
  echo "  Nach dem Beheben:  /perplexity-status"
fi
echo
