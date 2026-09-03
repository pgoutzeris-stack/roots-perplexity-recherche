#!/bin/bash
# End-to-end check: starts the MCP server the way Claude starts it and speaks
# the protocol to it. Proves that node, the key file, the npx download and the
# server itself all work together. Costs nothing: tools/list never reaches the
# Perplexity API.
#
#   verify-server.sh          human readable
#   verify-server.sh --quiet  only "OK: n Werkzeuge" or "FEHLER: ..."
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QUIET=0
[ "${1:-}" = "--quiet" ] && QUIET=1

command -v python3 >/dev/null 2>&1 || { echo "FEHLER: python3 fehlt"; exit 1; }

python3 - "$HERE/start-server.sh" "$QUIET" <<'PY'
import json, subprocess, sys, time

script, quiet = sys.argv[1], sys.argv[2] == "1"
EXPECTED = {"perplexity_search", "perplexity_ask", "perplexity_research"}

def out(msg):
    if not quiet:
        print(msg)

try:
    p = subprocess.Popen(["bash", script], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                         stderr=subprocess.PIPE, text=True, bufsize=1)
except Exception as e:
    print(f"FEHLER: Server liess sich nicht starten ({e})")
    sys.exit(1)

def send(obj):
    try:
        p.stdin.write(json.dumps(obj) + "\n")
        p.stdin.flush()
    except Exception:
        pass

def wait_for(msg_id, timeout):
    deadline = time.time() + timeout
    while time.time() < deadline:
        line = p.stdout.readline()
        if not line:
            return None
        try:
            msg = json.loads(line)
        except Exception:
            continue
        if msg.get("id") == msg_id:
            return msg
    return None

send({"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {
    "protocolVersion": "2024-11-05", "capabilities": {},
    "clientInfo": {"name": "roots-installer-check", "version": "1"}}})

# Beim ersten Lauf laedt npx das Server-Paket, das darf dauern.
init = wait_for(1, 120)
if init is None:
    err = ""
    try:
        p.kill()
        lines = [l.strip() for l in (p.stderr.read() or "").splitlines() if l.strip()]
        err = lines[-1] if lines else ""
    except Exception:
        pass
    # Nur den ersten Satz zeigen, sonst sprengt ein Pfad die Statuszeile.
    if err:
        err = err.split(". ")[0].split(" (")[0].rstrip(".")
        err = err[:90]
    print(f"FEHLER: Server startet nicht{(' — ' + err) if err else ''}")
    sys.exit(1)

if "error" in init:
    p.kill()
    print(f"FEHLER: Server meldet {init['error'].get('message', 'unbekannt')}")
    sys.exit(1)

info = init.get("result", {}).get("serverInfo", {})
out(f"  Server        {info.get('name', '?')} {info.get('version', '')}".rstrip())

send({"jsonrpc": "2.0", "method": "notifications/initialized", "params": {}})
send({"jsonrpc": "2.0", "id": 2, "method": "tools/list", "params": {}})

tools_msg = wait_for(2, 60)
p.kill()

if tools_msg is None or "result" not in tools_msg:
    print("FEHLER: Server nennt keine Werkzeuge")
    sys.exit(1)

names = {t.get("name") for t in tools_msg["result"].get("tools", [])}
missing = EXPECTED - names
if missing:
    print(f"FEHLER: Werkzeuge fehlen: {', '.join(sorted(missing))}")
    sys.exit(1)

if quiet:
    print(f"OK: {len(names)} Werkzeuge")
else:
    print(f"  Werkzeuge     {len(names)} gemeldet: {', '.join(sorted(names))}")
sys.exit(0)
PY
