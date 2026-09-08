# ROOTS Perplexity-Recherche

Externe Recherche läuft über die Perplexity-API, die Bewertung bleibt bei uns. Dazwischen steht ein Briefing aus sieben Leitplanken, die zu Beginn jeder Recherche festgelegt werden.

Jede Person nutzt einen eigenen API-Key. Damit ist der Verbrauch pro Person sichtbar, und ein unbedachter Deep-Research-Call trifft nur den eigenen Topf.

## Installation

Die geführte Seite: **https://pgoutzeris-stack.github.io/roots-perplexity-recherche/**

Oder ein Befehl im Terminal (Cmd+Leertaste, „Terminal", Enter):

```bash
curl -fsSL https://raw.githubusercontent.com/pgoutzeris-stack/roots-perplexity-recherche/main/install/setup.sh | bash
```

Der Ablauf führt durch sechs Schritte: Voraussetzungen, Konflikte, API-Key, Registrierung, Prüfung, Zusammenfassung. Fehlt Node.js, wird es ohne Adminrechte nach `~/.roots/node` entpackt.

Danach Claude mit Cmd+Q beenden und neu starten.

### Nur das Plugin, ohne Einrichtungshilfe

Wer seinen Key schon in `~/.roots/perplexity-key` hat, braucht nur den Marktplatz:

```
/plugin marketplace add pgoutzeris-stack/roots-perplexity-recherche
/plugin install roots-perplexity-recherche@roots-recherche
```

## Perplexity-Konto vorbereiten

Der Installer öffnet die Konsole selbst und zeigt diese Schritte. Hier zum Nachlesen:

| Schritt | Wo |
|---|---|
| Anmelden oder Konto anlegen | [perplexity.ai/settings/api](https://www.perplexity.ai/settings/api) |
| Key erzeugen | Menü **API Keys** ▸ Generate. Beginnt mit `pplx-`, wird nur einmal angezeigt |
| Guthaben aufladen | Menü **Billing** ▸ Add credits ▸ 5 Dollar |
| Monatliches Limit setzen | Menü **Billing** ▸ Monthly spend limit ▸ 20 Dollar |

Eine Suche kostet rund 1 Cent, eine Nachfrage wenige Cent. Ein einzelner Deep-Research-Call kostet 50 Cent bis 2 Dollar — deshalb das Limit.

## Wo der Key liegt

```
~/.roots/perplexity-key      Rechte 600, nur für dich lesbar
```

Nicht in der Claude-Konfiguration. Ein Ort für Rotation und Löschung. Der MCP-Server wird über ein Wrapper-Skript gestartet, das den Key beim Start liest.

## Befehle

| Befehl | Zweck |
|---|---|
| `/perplexity-status` | prüft Key, Rechte, Node, API-Erreichbarkeit und ob der Server startet |
| `/perplexity-key` | Key neu hinterlegen, mit Verifikation vor dem Speichern |

`/perplexity-status` startet den MCP-Server wie Claude ihn startet und fragt seine Werkzeugliste ab. Das ist der Beweis, dass die ganze Kette läuft, und kostet nichts.

## So wird es benutzt

Der Skill triggert von allein, sobald nach externen Fakten, Zahlen, Marktdaten oder Wettbewerbern gefragt wird:

1. Sieben Leitplanken als Fragen: Ziel, Suchraum, Zeitfenster, Quellen, Tiefe, Ausschlüsse, Output
2. Query-Plan zur Freigabe, mit Tool und Filter pro Query. Erst danach fließt Geld
3. Die Calls laufen, ohne Bewertung
4. Die Synthese passiert bei uns: Quellenkritik, Widersprüche, Lücken, Einordnung
5. Deliverable plus Quellentabelle und Recherche-Log

## Die drei Fehler, die beim ersten Mal passieren

**`research` nehmen, weil es nach dem gründlichsten Tool klingt.** Es nimmt keine Filter an, also greifen weder Domain-Allowlist noch Zeitfenster, und es kostet ein Vielfaches. Bei engen Vorgaben mehrere gefilterte `search`- und `ask`-Calls fahren.

**Die Leitplanken überspringen und Perplexity-Prosa direkt übernehmen.** Dann steht eine fremde Bewertung ohne nachvollziehbare Herleitung im Kundendokument. Der Wert entsteht in Schritt 4, nicht in Schritt 3.

**Pressemitteilungen für redaktionelle Belege halten.** Herstellerzahlen liegen auf den Domains seriöser Medien, erkennbar am Pfad `/adv/presseportal/`. Immer den Pfad ansehen, nicht nur den Domainnamen.

## Wieder entfernen

```bash
rm -rf ~/.roots/perplexity-key ~/.roots/node
```

Dazu in Claude `/plugin uninstall roots-perplexity-recherche@roots-recherche`.
