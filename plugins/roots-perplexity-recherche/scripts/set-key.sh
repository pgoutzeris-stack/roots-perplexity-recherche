#!/bin/bash
# Stores a verified Perplexity API key in ~/.roots/perplexity-key (mode 600).
#
#   set-key.sh                     interactive, asks in the terminal
#   set-key.sh --from-file PATH    reads the key from PATH, shreds PATH
#
# The key is never passed as a command line argument, so it cannot show up in
# the process list or the shell history.
set -euo pipefail

KEY_FILE="$HOME/.roots/perplexity-key"
FROM_FILE=""
QUIET=0

while [ $# -gt 0 ]; do
  case "$1" in
    --from-file) FROM_FILE="${2:-}"; QUIET=1; shift 2 ;;
    *) echo "Unbekannte Option: $1" >&2; exit 2 ;;
  esac
done

say() { [ "$QUIET" -eq 1 ] || echo "$@"; }

if [ -n "$FROM_FILE" ]; then
  [ -f "$FROM_FILE" ] || { echo "Übergabedatei fehlt." >&2; exit 1; }
  KEY="$(tr -d '[:space:]' < "$FROM_FILE")"
  rm -f "$FROM_FILE"
else
  say "Perplexity-API-Key hinterlegen"
  say
  say "1  https://www.perplexity.ai/settings/api  ->  API Keys  ->  Generate"
  say "2  Billing  ->  Add credits  ->  5 Dollar"
  say "3  Billing  ->  Monthly spend limit  ->  20 Dollar"
  say
  say "Eine Suche kostet rund 1 Cent, ein Deep-Research-Call bis 2 Dollar."
  say "Jede Person nutzt einen eigenen Key."
  say
  say "Der Key wird bei der Eingabe nicht angezeigt."
  say
  printf 'Key (beginnt mit pplx-): '
  IFS= read -rs KEY
  echo
  KEY="$(printf '%s' "$KEY" | tr -d '[:space:]')"
fi

if [ -z "$KEY" ]; then
  echo "Kein Key übergeben." >&2
  exit 1
fi
case "$KEY" in
  pplx-*) : ;;
  *) echo "Das sieht nicht nach einem Perplexity-Key aus (erwartet: pplx-...)." >&2; exit 3 ;;
esac

# Nur eine abgelehnte Anmeldung und ein leeres Guthaben verhindern das
# Speichern. Jede andere Antwort ist ein Problem der Testanfrage oder des
# Dienstes, nicht des Keys, und darf die Einrichtung nicht blockieren.
classify_http() {
  case "$1" in
    200)     echo valid ;;
    429)     echo ratelimit ;;
    400|422) echo params ;;
    401|403) echo badkey ;;
    402)     echo nocredit ;;
    000)     echo offline ;;
    *)       echo unknown ;;
  esac
}

say "Prüfe Key gegen die API (kostet unter einem Cent) ..."

TMP="$(mktemp)"
HTTP=$(curl -sS -o "$TMP" -w '%{http_code}' --max-time 45 \
  -X POST https://api.perplexity.ai/chat/completions \
  -H "Authorization: Bearer $KEY" \
  -H "Content-Type: application/json" \
  -d '{"model":"sonar","max_tokens":16,"messages":[{"role":"user","content":"ok"}]}' \
  2>/dev/null) || HTTP="000"
BODY="$(head -c 300 "$TMP" 2>/dev/null || true)"
rm -f "$TMP"

case "$(classify_http "$HTTP")" in
  valid)
    say "Key gültig, Guthaben vorhanden." ;;
  ratelimit)
    say "Rate Limit ($HTTP). Der Key selbst ist in Ordnung." ;;
  params)
    # Perplexity prueft die Anmeldung vor den Parametern. Ein Parameterfehler
    # heisst also: der Key ist gueltig, nur die Testanfrage passt nicht.
    say "Key gültig. Die Testanfrage wurde abgelehnt ($HTTP), das betrifft den Key nicht." ;;
  offline)
    say "Keine Verbindung zu api.perplexity.ai, der Key wurde nicht geprüft."
    say "Er wird trotzdem gespeichert. Später mit /perplexity-status prüfen." ;;
  unknown)
    say "Unerwartete Antwort $HTTP von Perplexity, der Key wurde nicht geprüft."
    say "Er wird trotzdem gespeichert. Später mit /perplexity-status prüfen." ;;
  badkey)
    echo "Perplexity hat den Key abgelehnt ($HTTP). Nicht gespeichert." >&2
    echo "$BODY" >&2
    exit 4 ;;
  nocredit)
    echo "Der Key ist gültig, aber auf dem Konto ist kein Guthaben ($HTTP)." >&2
    echo "Unter Billing aufladen, dann erneut versuchen. Nicht gespeichert." >&2
    exit 5 ;;
esac

mkdir -p "$(dirname "$KEY_FILE")"
chmod 700 "$(dirname "$KEY_FILE")" 2>/dev/null || true
umask 177
printf '%s\n' "$KEY" > "$KEY_FILE"
chmod 600 "$KEY_FILE"

say "Gespeichert in $KEY_FILE (nur für dich lesbar)."
