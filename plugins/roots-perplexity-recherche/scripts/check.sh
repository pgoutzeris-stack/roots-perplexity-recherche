#!/bin/bash
# Reports whether the setup is complete: key file, node, API reachability.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KEY_FILE="$HOME/.roots/perplexity-key"
FAIL=0

echo "Perplexity-Recherche — Status"
echo

if [ -f "$KEY_FILE" ]; then
  PERM="$(stat -f '%Lp' "$KEY_FILE" 2>/dev/null || echo '?')"
  echo "  Key-Datei     vorhanden (Rechte $PERM)"
  [ "$PERM" = "600" ] || { echo "                Rechte sollten 600 sein: chmod 600 $KEY_FILE"; FAIL=1; }
else
  echo "  Key-Datei     FEHLT — /perplexity-key ausfuehren"
  FAIL=1
fi

PLUG_ID="roots-perplexity-recherche@roots-recherche"
PLUG_STATE="$(python3 -c 'import json,os,sys; p=os.path.expanduser("~/.claude/plugins/installed_plugins.json")
try: d=json.load(open(p)).get("plugins",{})
except Exception: d={}
print("yes" if sys.argv[1] in d else "no")' "$PLUG_ID" 2>/dev/null)"
if [ "$PLUG_STATE" = "yes" ]; then
  echo "  Plugin        in Claude registriert"
else
  echo "  Plugin        NICHT registriert — Installer erneut starten"
  FAIL=1
fi

NODE_STATE="$(bash "$HERE/ensure-node.sh" --check 2>/dev/null)"
[ -n "$NODE_STATE" ] || NODE_STATE="absent"
case "$NODE_STATE" in
  system)
    NODE_BIN="$(bash "$HERE/ensure-node.sh" --bindir 2>/dev/null)/node"
    echo "  Node.js       systemweit ($("$NODE_BIN" -v 2>/dev/null || echo '?'))" ;;
  bundled) echo "  Node.js       mitgeliefert in ~/.roots/node ($("$HOME/.roots/node/bin/node" -v 2>/dev/null))" ;;
  *)       echo "  Node.js       FEHLT — Installer erneut starten"; FAIL=1 ;;
esac

if [ -f "$KEY_FILE" ]; then
  KEY="$(tr -d '[:space:]' < "$KEY_FILE")"
  HTTP=$(curl -sS -o /dev/null -w '%{http_code}' --max-time 30 \
    -X POST https://api.perplexity.ai/chat/completions \
    -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" \
    -d '{"model":"sonar","max_tokens":16,"messages":[{"role":"user","content":"ok"}]}' 2>/dev/null) || HTTP="000"
  # Nur eine abgelehnte Anmeldung und ein leeres Guthaben sind echte Mängel.
  # Alles andere sagt etwas über Netz oder Dienst, nicht über den Key.
  case "$HTTP" in
    200)     echo "  API           erreichbar, Key gueltig" ;;
    400|422) echo "  API           Key gueltig (Testanfrage abgelehnt: $HTTP)" ;;
    429)     echo "  API           Rate Limit ($HTTP) — Key selbst ist in Ordnung" ;;
    401|403) echo "  API           Key abgelehnt ($HTTP) — /perplexity-key erneut ausfuehren"; FAIL=1 ;;
    402)     echo "  API           kein Guthaben ($HTTP) — unter Billing aufladen"; FAIL=1 ;;
    000)     echo "  API           keine Verbindung — Key ungeprueft" ;;
    5??)     echo "  API           Dienst antwortet mit $HTTP — nicht der Key" ;;
    *)       echo "  API           unerwartete Antwort $HTTP — nicht der Key" ;;
  esac
fi

# Startet den Server wie Claude ihn startet und fragt seine Werkzeugliste ab.
# Das ist der einzige Beweis, dass die ganze Kette laeuft. Kostet nichts, weil
# tools/list die Perplexity-API nicht erreicht.
SRV="$(bash "$HERE/verify-server.sh" --quiet 2>&1)"
case "$SRV" in
  OK:*) echo "  Server        laeuft, ${SRV#OK: }" ;;
  *)    echo "  Server        ${SRV}"; FAIL=1 ;;
esac

echo
if [ "$FAIL" -eq 0 ]; then
  echo "Alles in Ordnung."
else
  echo "Offene Punkte oben."
fi
exit "$FAIL"
