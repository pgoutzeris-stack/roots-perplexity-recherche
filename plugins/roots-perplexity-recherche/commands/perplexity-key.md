---
description: Perplexity-API-Key hinterlegen oder erneuern
---

Fuehre `${CLAUDE_PLUGIN_ROOT}/scripts/set-key.sh` in einem Terminal aus, damit
der Nutzer den Key selbst eintippt. Frage den Key NIE im Chat ab und tippe ihn
nie selbst ein.

Nutze dazu:

```bash
osascript -e 'tell application "Terminal" to do script "bash \"${CLAUDE_PLUGIN_ROOT}/scripts/set-key.sh\""' -e 'tell application "Terminal" to activate'
```

Sage anschliessend, dass Claude nach dem Speichern einmal neu gestartet werden
muss, damit der MCP-Server den Key liest.
