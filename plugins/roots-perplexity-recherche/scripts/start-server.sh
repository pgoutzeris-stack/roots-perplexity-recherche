#!/bin/bash
# Starts the Perplexity MCP server. The API key lives in one file with mode 600
# instead of the Claude config, so it can be rotated or deleted in one place.
# If the machine has no node of its own, the copy under ~/.roots/node is used.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KEY_FILE="$HOME/.roots/perplexity-key"
BUNDLED_BIN="$HOME/.roots/node/bin"

if [ ! -f "$KEY_FILE" ]; then
  echo "Kein Perplexity-Key gefunden ($KEY_FILE). /perplexity-key ausfuehren." >&2
  exit 1
fi

KEY="$(tr -d '[:space:]' < "$KEY_FILE")"
if [ -z "$KEY" ]; then
  echo "Key-Datei ist leer ($KEY_FILE)." >&2
  exit 1
fi

# Ein systemweites node gewinnt; sonst greift die mitgelieferte Kopie. Der PATH
# wird nur fuer diesen Prozess erweitert, nichts am System veraendert.
#
# Wer diesen Server startet, bestimmt den PATH, und der kann minimal sein. Auf
# "command -v npx" allein ist deshalb kein Verlass: die Suche laeuft ueber
# ensure-node.sh, das zusaetzlich die Login-Shell befragt.
if ! command -v npx >/dev/null 2>&1; then
  NPX_DIR="$(bash "$HERE/ensure-node.sh" --bindir 2>/dev/null || true)"
  if [ -n "$NPX_DIR" ] && [ -x "$NPX_DIR/npx" ]; then
    PATH="$NPX_DIR:$PATH"
    export PATH
  elif [ -x "$BUNDLED_BIN/npx" ]; then
    PATH="$BUNDLED_BIN:$PATH"
    export PATH
  else
    echo "Kein npx gefunden. Installer erneut starten, er richtet Node.js ein." >&2
    exit 1
  fi
fi

export PERPLEXITY_API_KEY="$KEY"
exec npx -y @perplexity-ai/mcp-server
