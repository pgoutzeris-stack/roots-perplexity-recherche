-- ROOTS Perplexity-Recherche, GUI installer.
-- Native macOS dialogs, no terminal window. The payload sits in the app bundle
-- under Contents/Resources, so the app is the whole distribution.

property appTitle : "ROOTS Perplexity-Recherche"

on run
	activate
	set resDir to (POSIX path of (path to me)) & "Contents/Resources/"
	set engine to resDir & "plugins/roots-perplexity-recherche/scripts/engine.sh"
	set setKey to resDir & "plugins/roots-perplexity-recherche/scripts/set-key.sh"
	set checker to resDir & "plugins/roots-perplexity-recherche/scripts/check.sh"
	set nodeLog to (POSIX path of (path to home folder)) & ".roots/node-install.log"
	set repairLog to (POSIX path of (path to home folder)) & ".roots/repair.log"
	set restartLog to (POSIX path of (path to home folder)) & ".roots/restart.log"
	set restarter to resDir & "plugins/roots-perplexity-recherche/scripts/restart-claude.sh"
	
	-- ── Willkommen ───────────────────────────────────────────────
	set intro to "Dieser Installer richtet die Perplexity-Recherche in fünf Schritten ein." & return & return & "1.  Voraussetzungen prüfen und Laufzeitumgebung einrichten" & return & "2.  Kollidierende Plugins erkennen" & return & "3.  Eigenen API-Key anlegen und hinterlegen" & return & "4.  Plugin registrieren" & return & "5.  Einrichtung prüfen" & return & return & "Der API-Key bleibt auf diesem Rechner, in ~/.roots/perplexity-key mit Rechten 600. Er wird bei der Eingabe nicht angezeigt und landet weder in der Claude-Konfiguration noch in einem Chat." & return & return & "Die Recherche-Kosten laufen über dein eigenes Perplexity-Konto."
	activate
	if button returned of (display dialog intro with title appTitle buttons {"Abbrechen", "Installieren"} default button "Installieren" with icon note) is "Abbrechen" then return
	
	-- ── 1  Voraussetzungen ───────────────────────────────────────
	set pre to my sh("bash " & quoted form of engine & " preflight")
	set haveCLI to (pre contains "HAVECLI: 1")
	if pre contains "MISSING:" then
		activate
		display alert appTitle message ("Es fehlen Voraussetzungen:" & return & my afterToken(pre, "MISSING:")) as critical
		return
	end if
	
	-- Node.js wird bei Bedarf nach ~/.roots/node entpackt. Kein Passwort, keine
	-- Systemänderung, und ein spaeter installiertes node hat immer Vorrang.
	if pre contains "NODE: absent" then
		activate
		set progress total steps to 0
		set progress description to "Laufzeitumgebung wird eingerichtet"
		set progress additional description to "Etwa 50 MB werden geladen"
		
		do shell script "rm -f " & quoted form of nodeLog & "; nohup bash " & quoted form of engine & " nodeinstall >/dev/null 2>&1 &"
		
		set nodeDone to false
		set nodeFailed to ""
		repeat 300 times
			delay 1
			set tailLine to my sh("tail -n 1 " & quoted form of nodeLog & " 2>/dev/null")
			if tailLine starts with "FEHLER" then
				set nodeFailed to tailLine
				exit repeat
			else if tailLine starts with "FERTIG" then
				set nodeDone to true
				exit repeat
			else if tailLine is not "" then
				set progress additional description to tailLine
			end if
		end repeat
		
		set progress description to ""
		set progress additional description to ""
		
		if nodeFailed is not "" then
			set m to "Die Laufzeitumgebung konnte nicht eingerichtet werden." & return & return & nodeFailed & return & return & "Alternative: Node.js von nodejs.org installieren (LTS), dann diesen Installer erneut starten."
			activate
			if button returned of (display dialog m with title appTitle buttons {"Schließen", "nodejs.org öffnen"} default button "nodejs.org öffnen" with icon stop) is "nodejs.org öffnen" then
				do shell script "open https://nodejs.org/de/download"
				delay 1
				activate
			end if
			return
		end if
		if nodeDone is false then
			activate
			display alert appTitle message "Die Einrichtung der Laufzeitumgebung dauert ungewöhnlich lange und wurde abgebrochen. Netzverbindung prüfen und erneut starten." as critical
			return
		end if
	end if
	
	-- Das Serverpaket einmal festinstallieren. Ohne das laeuft jeder Start
	-- ueber npx, das das Paket neu aufloest: 0,75 s warm, 3,6 s kalt.
	set srvSh to resDir & "plugins/roots-perplexity-recherche/scripts/ensure-server.sh"
	if my sh("bash " & quoted form of srvSh & " --check") is not "local" then
		activate
		set progress total steps to 0
		set progress description to "Recherche-Server wird eingerichtet"
		set progress additional description to "Einmalig, danach startet er in etwa 0,1 s"
		my runBg("bash " & quoted form of srvSh & " --install", "server", 180)
		set progress description to ""
		set progress additional description to ""
	end if

	-- ── 2  Konflikte ─────────────────────────────────────────────
	set conflicts to my sh("bash " & quoted form of engine & " conflicts")
	if conflicts is not "" then
		set m to "Auf diesem Rechner ist bereits ein Perplexity-Plugin installiert:" & return & return & conflicts & return & return & "Zwei Plugins gleichzeitig liefern zwei Sätze gleich benannter Werkzeuge. Claude wählt dann unvorhersehbar, und die Kosten verteilen sich auf zwei Konten." & return & return & "Empfehlung: das andere zuerst mit  /plugin uninstall  entfernen."
		activate
		if button returned of (display dialog m with title appTitle buttons {"Abbrechen", "Trotzdem fortfahren"} default button "Abbrechen" with icon caution) is "Abbrechen" then return
	end if
	
	-- ── 3  API-Key ───────────────────────────────────────────────
	set needKey to true
	set keySkipped to false
	try
		do shell script "bash " & quoted form of engine & " haskey"
		set m to "Auf diesem Rechner liegt bereits ein Perplexity-Key." & return & return & "Behalten, oder einen neuen eintragen?"
		activate
		if button returned of (display dialog m with title appTitle buttons {"Neuen eintragen", "Behalten"} default button "Behalten" with icon note) is "Behalten" then set needKey to false
	end try
	
	if needKey then
		set m to "API-Key anlegen — vier Schritte in der Perplexity-Konsole." & return & return & ¬
			"1   Anmelden oder Konto anlegen" & return & ¬
			"     www.perplexity.ai/settings/api" & return & return & ¬
			"2   Key erzeugen" & return & ¬
			"     Menü »API Keys« ▸ Generate" & return & ¬
			"     Der Key beginnt mit  pplx-  und wird nur einmal angezeigt." & return & ¬
			"     Sofort kopieren." & return & return & ¬
			"3   Guthaben aufladen" & return & ¬
			"     Menü »Billing« ▸ Add credits ▸ 5 Dollar" & return & ¬
			"     Eine Suche kostet rund 1 Cent, eine Nachfrage wenige Cent." & return & ¬
			"     5 Dollar reichen für einige hundert Suchen." & return & return & ¬
			"4   Monatliches Limit setzen" & return & ¬
			"     Menü »Billing« ▸ Monthly spend limit ▸ 20 Dollar" & return & ¬
			"     Ein einzelner Deep-Research-Call kostet 50 Cent bis 2 Dollar." & return & ¬
			"     Ohne Limit gibt es keine Obergrenze."
		activate
		set keyMode to ""
		repeat
			activate
			try
				set b to button returned of (display dialog m with title appTitle buttons {"Ohne Key fortfahren", "Key eintragen", "Konsole öffnen"} default button "Konsole öffnen" with icon note)
			on error number -128
				return
			end try

			if b is "Konsole öffnen" then
				do shell script "open https://www.perplexity.ai/settings/api"
				delay 1
				activate
				set m to "Die Konsole ist im Browser offen." & return & return & ¬
					"Erledigt?" & return & return & ¬
					"·   Key erzeugt und kopiert  (API Keys ▸ Generate)" & return & ¬
					"·   5 Dollar aufgeladen  (Billing ▸ Add credits)" & return & ¬
					"·   Limit auf 20 Dollar gesetzt  (Billing ▸ Monthly spend limit)" & return & return & ¬
					"Dann »Key eintragen«."
			else if b is "Key eintragen" then
				set keyMode to "eintragen"
				exit repeat
			else
				-- Ohne Key: was dann nicht geht und wie es nachgeholt wird.
				activate
				set warn to "Ohne Key wird das Plugin installiert, aber es kann nicht recherchieren." & return & return & ¬
					"Was passiert:" & return & ¬
					"·   Die Recherche-Werkzeuge erscheinen in Claude" & return & ¬
					"·   Jeder Aufruf bricht mit  401 Unauthorized  ab" & return & ¬
					"·   Es entstehen keine Kosten" & return & return & ¬
					"Nachholen jederzeit, ohne den Installer:" & return & ¬
					"·   In Claude  /perplexity-key  eintippen" & return & ¬
					"·   Danach  /perplexity-status  zum Prüfen"
				try
					if button returned of (display dialog warn with title appTitle buttons {"Zurück", "Ohne Key fortfahren"} default button "Zurück" with icon caution) is "Ohne Key fortfahren" then
						set keyMode to "ohne"
						exit repeat
					end if
				on error number -128
					return
				end try
			end if
		end repeat

		if keyMode is "ohne" then
			set needKey to false
			set keySkipped to true
		end if
	end if

	if needKey then

		set stored to false
		repeat until stored
			set theKey to ""
			try
				activate
				set theKey to text returned of (display dialog "Perplexity-API-Key einfügen  (Cmd+V)" & return & return & "Beginnt mit  pplx-  · Eingabe wird nicht angezeigt" with title appTitle default answer "" buttons {"Abbrechen", "Prüfen und speichern"} default button "Prüfen und speichern" with icon note with hidden answer)
			on error number -128
				return
			end try
			
			-- Key über eine Datei mit Rechten 600 übergeben, damit er nicht in
			-- der Prozessliste auftaucht.
			set tmpPath to (POSIX path of (path to temporary items)) & "pplx-" & (do shell script "openssl rand -hex 8")
			do shell script "umask 177; : > " & quoted form of tmpPath
			set fh to open for access (POSIX file tmpPath) with write permission
			try
				write theKey to fh as «class utf8»
				close access fh
			on error e
				try
					close access fh
				end try
				do shell script "rm -f " & quoted form of tmpPath
				activate
				display alert appTitle message e as critical
				return
			end try
			
			try
				do shell script "bash " & quoted form of setKey & " --from-file " & quoted form of tmpPath
				set stored to true
			on error errMsg
				do shell script "rm -f " & quoted form of tmpPath & " 2>/dev/null || true"
				set m to "Der Key wurde nicht gespeichert." & return & return & my firstLines(errMsg, 4)
				activate
				if button returned of (display dialog m with title appTitle buttons {"Abbrechen", "Erneut versuchen"} default button "Erneut versuchen" with icon stop) is "Abbrechen" then return
			end try
		end repeat
	end if
	
	-- ── 4  Registrieren ──────────────────────────────────────────
	-- Nebenlaeufig ausgefuehrt: ein synchroner Aufruf blockiert den Ereignis-
	-- lauf der App fuer ein bis zwei Sekunden, und macOS zeigt dann den
	-- Wartecursor.
	activate
	set progress total steps to 0
	set progress description to "Plugin wird registriert"
	set progress additional description to ""
	set reg to my runBg("bash " & quoted form of engine & " register", "register", 90)
	set progress description to ""
	set progress additional description to ""
	set destPath to my sh("bash " & quoted form of engine & " dest")
	set wasInstalled to (reg contains "RESULT: installed")
	
	-- Schlaegt die stille Registrierung fehl, holt ein Terminal im Hintergrund
	-- sie mit echtem TTY nach. Die Claude-Code-Kommandozeile wartet auf manchen
	-- Rechnern auf Eingaben, die eine GUI-Shell nicht liefern kann.
	if not wasInstalled then
		if reg contains "RESULT: no-cli" then
			activate
			display dialog "Claude Code wurde auf diesem Rechner nicht gefunden." & return & return & "Der API-Key ist hinterlegt. Nach der Installation von Claude Code diesen Installer erneut starten, dann wird das Plugin registriert." with title appTitle buttons {"Schließen"} default button "Schließen" with icon stop
			return
		end if
		
		activate
		set progress total steps to 0
		set progress description to "Registrierung wird nachgeholt"
		set progress additional description to "Ein Terminal erledigt das im Hintergrund"
		
		do shell script "bash " & quoted form of engine & " repair"
		
		set repairDone to false
		set repairFailed to ""
		repeat 120 times
			delay 1
			set tailLine to my sh("tail -n 1 " & quoted form of repairLog & " 2>/dev/null")
			if tailLine starts with "FEHLER" then
				set repairFailed to tailLine
				exit repeat
			else if tailLine starts with "FERTIG" then
				set repairDone to true
				exit repeat
			else if tailLine is not "" then
				set progress additional description to tailLine
			end if
		end repeat
		
		set progress description to ""
		set progress additional description to ""
		
		if repairDone then
			set wasInstalled to true
		else
			set m to "Das Plugin konnte nicht registriert werden."
			if repairFailed is not "" then set m to m & return & return & repairFailed
			set m to m & return & return & "Der API-Key ist hinterlegt. In Claude Code eintippen:" & return & return & "/plugin marketplace add " & destPath & return & "/plugin install roots-perplexity-recherche@roots-recherche"
			activate
			display dialog m with title appTitle buttons {"Verstanden"} default button "Verstanden" with icon caution
		end if
	end if
	
	-- ── 5  Prüfen ────────────────────────────────────────────────
	activate
	set progress total steps to 0
	set progress description to "Einrichtung wird geprüft"
	set progress additional description to "Der Recherche-Server wird gestartet und befragt"
	
	set checkOut to ""
	set checkOK to true
	try
		set checkOut to my runBg("bash " & quoted form of checker, "check", 180)
	on error errMsg
		set checkOut to errMsg
		set checkOK to false
	end try
	
	set progress description to ""
	set progress additional description to ""
	
	if keySkipped and wasInstalled then
		activate
		set m to "Das Plugin ist installiert, es fehlt nur der Key." & return & return & ¬
			"So machst du es einsatzbereit:" & return & return & ¬
			"1   Claude mit Cmd+Q beenden und neu starten" & return & ¬
			"2   In Claude  /perplexity-key  eintippen" & return & ¬
			"3   Mit  /perplexity-status  prüfen" & return & return & ¬
			"Bis dahin melden die Recherche-Werkzeuge  401 Unauthorized.  Es entstehen keine Kosten."
		display dialog m with title appTitle buttons {"Schließen"} default button "Schließen" with icon caution
		return
	end if

	if checkOK and wasInstalled then
		set m to "Fertig." & return & return & ¬
			"Claude muss einmal neu starten, damit der Recherche-Server läuft und den Key liest." & return & return & ¬
			"»Claude neu starten« erledigt das jetzt: die App wird beendet und wieder geöffnet. Offene Unterhaltungen in der App werden dabei geschlossen." & return & return & ¬
			"Danach fragt der Skill von allein sieben Leitplanken ab und legt einen Query-Plan zur Freigabe vor. Erst nach deinem Ja fließt Geld." & return & return & ¬
			"Jederzeit prüfen:  /perplexity-status" & return & "Key erneuern:  /perplexity-key"
		activate
		if button returned of (display dialog m with title appTitle buttons {"Später selbst", "Claude neu starten"} default button "Claude neu starten" with icon note) is "Claude neu starten" then
			activate
			set progress total steps to 0
			set progress description to "Claude wird neu gestartet"
			set progress additional description to ""
			
			do shell script "rm -f " & quoted form of restartLog & "; nohup bash " & quoted form of restarter & " >/dev/null 2>&1 &"
			
			set rDone to false
			set rFailed to ""
			repeat 70 times
				delay 1
				set tailLine to my sh("tail -n 1 " & quoted form of restartLog & " 2>/dev/null")
				if tailLine starts with "FEHLER" then
					set rFailed to tailLine
					exit repeat
				else if tailLine starts with "FERTIG" then
					set rDone to true
					exit repeat
				else if tailLine is not "" then
					set progress additional description to tailLine
				end if
			end repeat
			
			set progress description to ""
			set progress additional description to ""
			
			if rDone then
				activate
				display dialog "Claude läuft wieder, die Recherche-Werkzeuge sind geladen." & return & return & "Frag einfach nach externen Zahlen oder Marktdaten, der Skill meldet sich von allein." with title appTitle buttons {"Schließen"} default button "Schließen" with icon note
			else
				set m2 to "Der Neustart hat nicht geklappt."
				if rFailed is not "" then set m2 to m2 & return & return & rFailed
				set m2 to m2 & return & return & "Claude von Hand mit Cmd+Q beenden und wieder öffnen. Die Einrichtung selbst ist fertig."
				activate
				display dialog m2 with title appTitle buttons {"Verstanden"} default button "Verstanden" with icon caution
			end if
		end if
	else
		activate
		display dialog ("Die Prüfung hat offene Punkte gemeldet:" & return & return & checkOut) with title appTitle buttons {"Schließen"} default button "Schließen" with icon caution
	end if
end run

-- Läuft ein Shell-Kommando und liefert stdout ohne Leerzeilen am Rand.
on sh(cmd)
	try
		return do shell script cmd
	on error errMsg number errNum
		if errNum is 1 then return ""
		error errMsg number errNum
	end try
end sh

-- Text nach einem Marker, bis zum Zeilenende.
on afterToken(hay, marker)
	set AppleScript's text item delimiters to marker
	set tail to text item 2 of hay
	set AppleScript's text item delimiters to return
	set out to text item 1 of tail
	set AppleScript's text item delimiters to ""
	return out
end afterToken

-- Erste n Zeilen, damit Fehlermeldungen den Dialog nicht sprengen.
on firstLines(t, n)
	set AppleScript's text item delimiters to return
	set ls to text items of t
	set AppleScript's text item delimiters to ""
	if (count of ls) ≤ n then return t
	set out to ""
	repeat with i from 1 to n
		set out to out & item i of ls
		if i < n then set out to out & return
	end repeat
	return out
end firstLines

-- Fuehrt ein Kommando im Hintergrund aus und wartet mit delay darauf. delay
-- verarbeitet weiter Ereignisse, ein synchrones do shell script nicht: dort
-- steht die App und macOS zeigt den Wartecursor.
on runBg(shellCmd, tag, maxSeconds)
	set outPath to (POSIX path of (path to home folder)) & ".roots/" & tag & ".out"
	set q to quoted form of outPath
	do shell script "mkdir -p " & quoted form of ((POSIX path of (path to home folder)) & ".roots") & "; rm -f " & q
	do shell script "( " & shellCmd & " > " & q & " 2>&1; echo __ENDE__ >> " & q & " ) >/dev/null 2>&1 &"
	repeat maxSeconds times
		delay 1
		set t to my sh("cat " & q & " 2>/dev/null")
		if t contains "__ENDE__" then
			set AppleScript's text item delimiters to "__ENDE__"
			set t to text item 1 of t
			set AppleScript's text item delimiters to ""
			do shell script "rm -f " & q
			return t
		end if
	end repeat
	do shell script "rm -f " & q
	return ""
end runBg
