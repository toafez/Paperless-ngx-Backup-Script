# Paperless-ngx Backup-Script

## Worum geht es?
Mithilfe des hier vorgestellten Skripts sollen der Export und die anschließende lokale Sicherung von Datenbankinhalten, Metadaten, Benutzerprofilen, Einstellungen usw. von Paperless-ngx erleichtert werden. Hierzu werden Funktionen genutzt, die sowohl Paperless-ngx als auch PostgreSQL selbst anbieten. Mit rsync werden darüber hinaus weitere wichtige Konfigurationsdateien wie die YAML- und die ENV-Datei gesichert. **Das eigentliche Dockerverzeichnis von Paperless-ngx (z.B. /volume1/docker/Pakerless-ngx) wird dabei jedoch nicht gesichert**, da mit den oben genannten Export-Funktionen und rsync-Aufgaben bereits alle relevanten Daten für eine spätere Wiederherstellung erfasst wurden.

#### _Hinweis: Texte in Großbuchstaben, die sich innerhalb oder außerhalb eckiger Klammern befinden, dienen als Platzhalter und müssen durch eigene Angaben ersetzt werden, können aber an einigen Stellen auch nur der Information dienen. Es ist zu beachten, dass die eckigen Klammern Teil des Platzhalters sind und beim Ersetzen durch eigene Angaben ebenfalls entfernt werden müssen._

## So funktioniert das Skript genau

- **Erstellung eines Datensicherungsprotokolls**  
Zunächst wird im angegebenen Datensicherungsziel ein neues Protokoll erstellt, das im Folgenden mit Informationen zum aktuellen Sicherungsverlauf beschrieben wird. Dabei wird das mitlaufende Protokoll auch in Echtzeit auf der Kommandozeile ausgegeben. 

- **Ausführung der integrierten Exportfunktion von Paperless-ngx**  
Zum Exportieren vorhandener Datenbankinhalte, Metadaten, Benutzerprofile und -einstellungen etc. bietet Paperless-ngx mit dem `document_exporter` eine eigene Funktion an. Vor der Ausführung dieser Funktion wird zunächst geprüft, ob der Paperless-ngx-Container läuft, da der Export sonst nicht ausgeführt werden kann. Die exportierten Daten werden im Unterverzeichnis `/export` des Paperless-ngx-Verzeichnisses abgelegt. 

- **Sicherung des Exportverzeichnis `/export`**  
Nach Abschluss des Exports werden die Daten aus dem Ordner `/export` in das lokale Ziel der Datensicherung übertragen.

- **Ausführung der integrierten Exportfunktion (Dump) von PostgreSQL**  
Zum Exportieren der eigentlichen Datenbankinhalte bietet PostgreSQL mit `pg_dump` eine eigene Funktion an. Dabei werden die zu exportierenden Datenbankinhalte direkt ins lokale Datensicherungsziel übertragen und in einer Datei mit der Dateiendung `.sql` gespeichert. Vor der Ausführung dieser Funktion wird zunächst geprüft, ob der PostgreSQL Container von Paperless-ngx läuft, da der Export sonst nicht ausgeführt werden kann.
 
- **Sicherung des YAML- bzw. Docker-Compose-Datei**  
Befindet sich im Hauptverzeichnis von Paperless-ngx eine YAML- bzw. Docker-Compose-Datei, wird diese ins lokale Datensicherungsziel übertragen und als Datei mit der Endung `.yaml` gespeichert. Befindet sich die Datei an einem anderen Ort, kann im Skript optional der Pfad und der Dateiname angepasst werden. 

- **Sicherung des ENV- bzw. Environment-Datei**  
Befindet sich im Hauptverzeichnis von Paperless-ngx eine ENV-Datei, wird diese ins lokale Datensicherungsziel übertragen und als Datei mit der Endung `.env` gespeichert. Befindet sich die Datei an einem anderen Ort, kann im Skript optional der Pfad und der Dateiname angepasst werden. 

- **Anpassen der Ordner- und Dateirechte im Sicherungsziel**  
Abschließend werden die Ordner- und Dateirechte im Datensicherungsziel noch an die im Skript angegebenen Benutzer- und Gruppenrechte angepasst.


## Installationshinweise
Mit Hilfe des Kommandozeilenprogramms `curl` kann die Shell-Skript-Datei **Paperless-ngx-Backup-Script.sh** einfach über ein Terminalprogramm deiner Wahl heruntergeladen werden. Als Speicherort bietet sich das eigene Benutzer-Home-Verzeichnis an, es kann jedoch auch jedes andere erreichbare Verzeichnis verwendet werden. Wechsle in das von dir gewählte Verzeichnis. Führe dann den folgenden Befehl aus. Damit wird die Skriptdatei in das ausgewählte Verzeichnis heruntergeladen.

**Download der Shell-Skript-Datei Paperless-ngx-Backup-Script.sh**

	curl -L -O https://raw.githubusercontent.com/toafez/Paperless-ngx-Backup-Script/refs/heads/main/scripts/Paperless-ngx-Backup-Script.sh
	

Führe anschließend im selben Verzeichnis den folgenden Befehl aus, um der Shell-Skript-Datei **Paperless-ngx-Backup-Script.sh** Ausführungsrechte zu erteilen.

	chmod +x Paperless-ngx-Backup-Script.sh

## Skript manuell ausführen
Die Shell-Skript-Datei `Paperless-ngx-Backup-Script.sh` sollte **immer** mit Root-Berechtigungen (d. h. mit vorangestelltem sudo-Befehl) oder als Root selbst ausgeführt werden ausgeführt werden.

Der Aufruf selbst erfolgt am besten, indem man den absoluten Pfad, d.h. den Verzeichnispfad, in dem sich die Shell-Skript-Datei `Paperless-ngx-Backup-Script.sh` befindet, voranstellt, wobei auch der relative Pfad genügt, wenn man sich selbst im selben Verzeichnis wie das Shell-Skript befindet. 

Aufruf mit dem absoluten Pfad:

	sudo /PFAD/ZUM/SKRIPT/Paperless-ngx-Backup-Script.sh

Aufruf mit dem relativen Pfad:

	sudo ./Paperless-ngx-Backup-Script.sh


## Skript automatisiert über einen Cron-Job ausführen

Erstelle einen systemweiten Cron-Job, der später mit Root-Berechtigungen ausgeführt wird. Führe dazu den folgenden Befehl aus:

```
sudo crontab -e
```
	
Nach dem Aufruf und der eventuellen Aufforderung, einen bevorzugten Editor zum Bearbeiten der crontab auszuwählen – ich empfehle an dieser Stelle den Editor `nano` – wird an geeigneter Stelle, bestenfalls ganz am Ende des Dokuments, folgender Befehl in abgewandelter Form bzw. nach eigenen Anforderungen eingegeben:

Syntax: 
```
* * * * * bash /PFAD/ZUM/SKRIPT/DATEINAME.sh
┬ ┬ ┬ ┬ ┬ ┬
│ │ │ │ │ └─ SKript/Kommando
│ │ │ │ └─── Wochentag (0-7, Sonntag ist 0 oder 7)
│ │ │ └───── Monat (1-12)
│ │ └─────── Tag (1-31)
│ └───────── Stunde (0-23)
└─────────── Minute (0-59)

Um mehrere spezifische Werte für eine Aufgabe festzulegen, können Felder wie Stunden, Minuten, Tage, Monate oder Wochentage durch Kommata getrennt werden.
```

Beispiel:
Ausführung des Skripts jeden Montag und Freitag um 6:00 Uhr
```
0 6 * * 1,5 bash /PFAD/ZUM/SKRIPT/paperless-backup.sh
```

## Beispielausgabe
Nachfolgend ist eine beispielhafte Protokollausgabe auf der Kommandozeile zu sehen, die entsteht, nachdem das Skript ausgeführt wurde. 
```
---------------------------------------------------------------------------------------------------------
Paperless-ngx Datensicherungsprotokoll vom 18.12.2025 um 06:00:00 Uhr
 - Datensicherungsziel: /volume2/Datensicherung/Paperless-ngx
---------------------------------------------------------------------------------------------------------

Die integrierte Exportfunktion von Paperless-ngx wird ausgeführt....
100%|██████████| 2117/2117 [00:02<00:00, 739.84it/s]
 - Der Paperless-NGX-Exportordner wurde gesichert.
 - Die PostgreSQL-Datenbank wurde gesichert.
 - Die YAML-Datei wurde gesichert.
 - Die Ordner- und Dateirechte im Sicherungsziel wurden auf [ tommes:admin ] gesetzt.

---------------------------------------------------------------------------------------------------------
```

## Versionsgeschichte
- Details zur Versionsgeschichte findest du in der Datei [CHANGELOG](CHANGELOG)

## Hilfe und Diskussion
- Hilfe und Diskussionen gerne über das UGREEN Forum - DACH Community (Link folgt)

## Lizenz
- MIT License [LICENSE](LICENSE)
