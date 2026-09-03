---
name: perplexity-recherche
description: Steuert jede externe Recherche über den Perplexity-MCP-Server, während Bewertung und Synthese in Cowork bleiben. Der Ablauf ist immer: sieben Leitplanken abfragen, Query-Plan zur Freigabe vorlegen, Perplexity-Calls ausführen, in Cowork synthetisieren, Deliverable mit Quellentabelle und Recherche-Log liefern. Triggert bei jeder Anfrage nach externen Fakten, Zahlen, Marktdaten, Wettbewerbern, Marken, Kampagnen, Personen oder Unternehmen — auch indirekt formuliert ("recherchier mal", "was gibt es zu X", "such mir Quellen zu", "wie machen das die Wettbewerber", "gibt es Zahlen zu", "was ist der aktuelle Stand bei", "brief mich zu Firma Y"). Auch triggern, wenn ohne das Wort Recherche nach aktuellen externen Informationen gefragt wird. NICHT verwenden für Recherche in internen Quellen (Notion, SharePoint, Outlook, angehängte Dateien), für reine Wissensfragen ohne Aktualitätsbezug, für Textarbeit an bereits vorliegendem Material oder wenn ausdrücklich WebSearch statt Perplexity verlangt wird.
---

# Perplexity-Recherche

Recherche läuft extern über Perplexity, das Denken bleibt intern in Cowork. Diese Trennung ist der Zweck des Skills und darf nicht abgekürzt werden, auch nicht bei kleinen Fragen.

Jeder Call kostet Geld über den API-Key der Person, mit der du arbeitest. Behandle Budget als knappe Ressource.

## Voraussetzung prüfen

Die vier Tools enden auf `perplexity_search`, `perplexity_ask`, `perplexity_research` und `perplexity_reason`. Der Präfix hängt davon ab, wie der Server angebunden ist: über die Desktop-Brücke heißen sie `mcp__remote-devices__Perplexity__…`, über dieses Plugin tragen sie den Plugin-Präfix. Suche sie deshalb per ToolSearch mit dem Stichwort `perplexity` und lade alle benötigten in EINEM Aufruf.

Fehlen sie ganz: sagen, dass der Perplexity-Server in dieser Session nicht erreichbar ist, und auf die drei üblichen Ursachen hinweisen (Desktop-App nicht verbunden, `PERPLEXITY_API_KEY` nicht gesetzt, kein Guthaben auf dem Key). Dann fragen, ob stattdessen mit WebSearch gearbeitet werden soll. Nicht stillschweigend auf WebSearch ausweichen.

## Schritt 1 — Leitplanken abfragen

Sieben Felder, per AskUserQuestion kompakt gebündelt (max. 4 Fragen pro Aufruf, also zwei Runden oder sinnvoll zusammengefasst). Keine Vorbelegung aus früheren Recherchen; bei knappen Angaben einen Vorschlag machen, der überschrieben werden kann.

1. **Ziel und Entscheidung** — was soll beantwortet werden, welche Entscheidung hängt daran, wann hören wir auf
2. **Suchraum** — Märkte, Länder, Sprachen
3. **Zeitfenster** — relativ oder absolut
4. **Quellen** — Allowlist ODER Blocklist (max. 20 Domains, nie gemischt) plus Quellenklassen
5. **Tiefe und Budget** — Anzahl Queries, welches Tool
6. **Ausschlüsse** — Namensdoppel, Nachbarmärkte, alte Wellen, gesperrte Beispiele bei Kundenkonflikten
7. **Output** — Format, Länge, Sprache, Zitierpflicht, Konfidenzmarkierung

Feld 6 ist bei ROOTS besonders wichtig: Marken von Bestandskunden dürfen nicht als Negativbeispiel dienen. Aktiv danach fragen.

## Schritt 2 — Query-Plan zur Freigabe

Drei bis acht Queries als Tabelle: Query, Tool, Filter, beantwortete Frage. Erst nach Freigabe ausführen.

| Tool | Einsatz |
|---|---|
| `perplexity_search` | Quellen sammeln, Existenz prüfen, ein Feld unter Domain-Filter abscannen. Liefert Titel, URL, Snippet und Datum pro Treffer. Günstigster Call |
| `perplexity_ask` | einzelne Fakten und Zahlen klären, Gegenprüfung |
| `perplexity_research` | nur wenn das Feld bewusst weit sein soll. Teuer, langsam, und nimmt keine Filter an |
| `perplexity_reason` | **nicht verwenden** — Bewertung bleibt in Cowork |

## Filter-Matrix — geprüft 01.09.2026

| Parameter | search | ask | research | reason |
|---|---|---|---|---|
| `search_domain_filter` | ja | ja | **nein** | ja |
| `search_recency_filter` (hour…year) | ja | ja | **nein** | ja |
| `country` (ISO-2) | ja | nein | nein | nein |
| `max_results` (1–20) | ja | — | — | — |
| `max_tokens_per_page` (256–2048) | ja | — | — | — |
| `search_context_size` | — | ja | nein | ja |
| absolutes Datumsfenster | **nein** | **nein** | **nein** | **nein** |

Domain-Filter: Allowlist `["horizont.net", "wuv.de"]` oder Blocklist `["-reddit.com"]`, nie gemischt, max. 20 Einträge.

Drei Konsequenzen, die den Query-Plan bestimmen:

- **Enge Leitplanken schließen `research` aus.** Sind Domains, Zeitfenster oder Markt vorgegeben, mehrere gefilterte `search`- und `ask`-Calls fahren statt einen `research`-Call. Sonst laufen die Leitplanken ins Leere und das Ergebnis sieht nur präzise aus.
- **Absolute Zeitfenster nachfiltern.** Das Fenster in die Query schreiben, dann die Treffer anhand der mitgelieferten Datumsangaben selbst aussortieren, und sagen, dass diese Leitplanke nur als Formulierung wirkt.
- **Eine zu enge Allowlist kann eine Frage unbeantwortbar machen.** Marktanteile und Studienzahlen liegen bei Marktforschern und in Investorenmaterial, nicht in der Fachpresse. Solche Queries ohne Allowlist fahren und das im Plan ausweisen.

## Schritt 3 — Ausführen

Calls nach Plan. Hier nicht bewerten, nur sammeln. Jede Aussage mit Quelle und Datum mitschreiben. Weicht die Trefferlage deutlich vom Erwarteten ab (kaum Treffer, offensichtlich falsches Thema, widersprüchliche Grundannahme), vor der nächsten Runde melden statt weiterzusuchen. Greift eine Allowlist ins Leere, das benennen statt die Liste stillschweigend zu weiten.

## Schritt 4 — Synthese in Cowork

Erst hier denken:

- **Quellenklasse prüfen, nicht nur die Domain.** Pressemitteilungen liegen auf den Domains seriöser Medien, erkennbar an Pfaden wie `/adv/`, `/presseportal/` oder `/pm/`. Eine Herstellerzahl aus so einem Pfad ist Selbstauskunft, kein redaktionell geprüfter Beleg, und muss als solche markiert oder ersetzt werden.
- Widersprüche zwischen Quellen benennen statt glätten, auch wenn sie aus derselben Publikation kommen.
- Lücken markieren: was gefunden wurde, was nicht auffindbar war. Ein Fehlen von Belegen ist kein Beleg für ein Fehlen.
- In ROOTS-Logik einordnen und ableiten, was das für die Entscheidung aus Feld 1 heißt.
- Zahlen ohne Primärquelle als unbelegt markieren, nicht als Fakt setzen.
- **Belege und Behauptung gegeneinander prüfen.** Wenn das Deliverable eine Ursache behauptet, müssen die Fälle diese Ursache belegen und keine andere. Passt der Fall nicht zur Behauptung, ist es der falsche Fall, nicht die falsche Formulierung.

## Schritt 5 — Deliverable

Im vereinbarten Format, plus zwei Anhänge:

- **Quellentabelle**: Aussage, Quelle, URL, Datum, Quellenklasse
- **Recherche-Log**: die sieben Leitplanken und alle ausgeführten Queries inklusive Filter, dazu die nicht verwendeten Funde und die Lücken

## Verifikation vor der Abgabe

- Beantwortet das Ergebnis die Frage aus Feld 1, oder nur eine benachbarte?
- Steht hinter jeder Zahl eine Quelle mit Datum und Quellenklasse?
- Sind die Leitplanken eingehalten, Zeitfenster, Suchraum, Ausschlüsse?
- Wurde eine Leitplanke nur als Formulierung wirksam? Dann ist sie im Log als solche markiert.
- Belegt jeder Fall die Behauptung, neben der er steht?
- Ist irgendwo eine Bewertung von Perplexity durchgereicht statt selbst hergeleitet?
- Sind Unsicherheiten markiert statt weggeschrieben?
