#!/bin/bash
# Filename: Paperless-ngx-Backup-Script.sh - coded in utf-8
version="1.0-400"


#             Backupskript für Paperless-ngx
#    Copyright (C) 2026 by tommes (toafez) | MIT License


# --------------------------------------------------------------
# Verbindliche, benutzerspezifische Angaben
# --------------------------------------------------------------

# Pfad zum lokalen Datensicherungsziel
backup_dir="/Absoluter/Pfad/zum/Datensicherungsziel"

# Dateiname des Sicherungsprotokolls
logfile_name="Protokoll_der_letzten_Sicherung.log"

# Pfad des zu sichernden Docker-Projekts
project_dir="/Absoluter/Pfad/zum/Paperless-ngx-Verzeichnis"

# Dienst- bzw. Servicename des Docker-Projekts
project_service_name="webserver"

# Containername oder ID des Docker-Projekts
project_container_name="Paperless-ngx"

# Dienst- bzw. Servicename der PostgreSQL-Datenbank
postgres_service_name="db"

# Containername oder ID der PostgreSQL-Datenbank
postgres_container_name="Paperless-ngx-PostgreSQL"

# Benutzername für die PostgreSQL-Datenbank
postgresql_user="paperless"

# Passwort für die PostgreSQL-Datenbank
postgresql_db="paperless"

# Angabe einer Zeit in Tagen, wie lange Versionsordner behalten
# werden sollen, bevor sie gelöscht werden. Der Wert 0 bedeutet,
# dass keine Versionsordner erstellt werden.
version_history="0"


# --------------------------------------------------------------
# Rock ’n’ Roll...
# --------------------------------------------------------------

# Skript sofort beenden wenn Fehlerstatus ungleich null ist
set -e

# Rückgabewert auf den ersten fehlerhaften Befehl innerhalb der Pipeline setzen
set -o pipefail

# Funktion: Aktuelles Datum
datestamp() { date +"%d.%m.%Y"; }

# Funktion: Aktuelle Uhrzeit
timestamp() { date +"%H:%M:%S"; }

# Funktion: Aktuelles Datum und Uhrzeit für die Bezeichnung der Versionsordner
datetime_dir() { date +"%Y-%m-%dT%H-%M-%S"; }

# Absoluten Pfad des Shell-Skripts ermitteln
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

# Wenn die Versionierung aktiviert ist, leite das Datensicherungsziel in einen Versionsordner um
[[ "${version_history}" =~ ^[1-9][0-9]*$ ]] && backup_dir="${backup_dir}/$(datetime_dir)"

# Falls noch nicht vorhanden, Datensicherungsziel erstellen
[[ ! -d "${backup_dir}" ]] && mkdir -p "${backup_dir}"

# Falls das Datensicherungsziel exisitiert...
if [[ -d "${backup_dir}" ]]; then

    # Pfad zur Protokolldatei festlegen
    [[ "${version_history}" =~ ^[1-9][0-9]*$ ]] && logfile="${backup_dir%/*}/${logfile_name}" || logfile="${backup_dir}/${logfile_name}"

    # Erstelle/überschreibe Protokolldatei
    : > "${logfile}"

    # Funktion: Schreibe Daten in die Protokolldatei
    log() { printf '%s\n' "$*" | tee -a "${logfile}"; }
    hr="---------------------------------------------------------------------------------------------------------"

    # Beginn des Protokolls...

    # Prüfen, ob das verwendete Skript aktuell ist oder ob ein Update auf GitHub verfügbar ist
    git_version=$(wget --no-check-certificate --timeout=60 --tries=1 -q -O- "https://raw.githubusercontent.com/toafez/Paperless-ngx-Backup-Script/refs/heads/main/Paperless-ngx-Backup-Script.sh" | grep ^version= | cut -d '"' -f2)		
    if [ -n "${git_version}" ] && [ -n "${version}" ]; then
        if dpkg --compare-versions ${git_version} gt ${version}; then
            log "${hr}"
            log "WICHTIGER HINWEIS:"
            log "Auf GitHub steht ein Update für dieses Skript zur Verfügung."
            log "Bitte aktualisiere deine Version ${version} auf die neue Version ${git_version}."
            log "Link: https://github.com/toafez/Paperless-ngx-Backup-Script"
            log "${hr}"
            log ""
        fi
    fi

    # Wenn das Hauptverzeichnis des Docker-Projekts existiert...
    if [[ -d "${project_dir}" ]]; then

        # Prüfen, welchem Benutzer bzw. welcher Gruppe das Docker-Projekt Verzeichnis gehört
        dir_user=$(stat -c '%U' "${project_dir}")
        dir_group=$(stat -c '%G' "${project_dir}")

        log "${hr}"
        log "${project_container_name} Datensicherungsprotokoll vom $(datestamp) um $(timestamp) Uhr"
        log " - Datensicherungsziel: ${backup_dir}"
        log "${hr}"
        log ""

        # Prüfe, ob Paperless-ngx über den Service- oder den Containernamen erreichbar ist, und passe den Docker-Befehl entsprechend an
        if cd "${project_dir}" 2>/dev/null && [[ -n "$(docker compose ps --status running -q "${project_service_name}")" ]]; then
            docker_command="docker compose exec -T ${project_service_name}"
        elif docker inspect -f '{{.State.Running}}' -- "${project_container_name}" 2>/dev/null | grep -q '^true$'; then
            docker_command="docker exec -T ${project_container_name}"
        else
            docker_command=
        fi

        # Führe den festgelegten Docker-Befehl aus
        if [[ -n "${docker_command}" ]]; then

            # Wechsle ins Hauptverzeichnis des Docker-Projekts
            cd "${project_dir}"

            # Sichern aller Dokumente in das Paperless-NGX-Exportverzeichnis
            log "Die integrierte Exportfunktion von Paperless-ngx wird ausgeführt. Bitte warten..."
            ${docker_command} document_exporter ../export -d -p -z
                # -d    : Löscht Dateien aus dem Exportverzeichnis, die in Paperless-ngx nicht mehr vorhanden sind.
                # -p    : Dateien werden in die entsprechenden Unterordner /archive, /originals und /thumbnails sortiert.
                # -z    : Der Inhalt des Exportverzeichnisses wird in einer ZIP-Datei nach der Syntax export-YYYY-MM-DD.zip archiviert.
                #         Der document_importer kann solch ein ZIP-Archiv verarbeiten.

            # Wechsle zurück ins Skriptverzeichnis
            cd "${script_dir}"

            # Prüfen, ob Dokumente im Paperless-NGX-Exportverzeichnis vorhanden sind
            if [[ -n "$(ls -A ${project_dir}/export)" ]]; then

                # Sichern aller exportierten Dokumente aus dem Paperless-NGX-Exportverzeichnis ins Datensicherungsziel
                rsync -a --delete ${project_dir}/export ${backup_dir}

                # Prüfen, ob Dokumente im Datensicherungsziel vorhanden sind
                if [[ -d "${backup_dir}/export" ]]; then
                    log " - Das Paperless-NGX-Exportverzeichnis [ /export ] wurde gesichert."
                else
                    log " - Die Sicherung des Paperless-NGX-Exportverzeichnises war nicht möglich."
                fi
            else
                log " - Die Bereitstellung der Dokumente im Paperless-NGX-Exportverzeichnis war nicht möglich."
            fi

            # Variable des Docker-Befehls leeren
            docker_command=
        else
            log " - Die Sicherung des Paperless-NGX-Exportverzeichnises konnte nicht durchgeführt"
            log "   werden, da der Container aktuell nicht ausgeführt wird!"
        fi

        # Prüfe, ob PostgreSQL über den Service- oder den Containernamen erreichbar ist, und passe den Docker-Befehl entsprechend an
        if cd "${project_dir}" 2>/dev/null && [[ -n "$(docker compose ps --status running -q "${postgres_service_name}")" ]]; then
            docker_command="docker compose exec -T ${postgres_service_name}"
        elif docker inspect -f '{{.State.Running}}' -- "${postgres_container_name}" 2>/dev/null | grep -q '^true$'; then
            docker_command="docker exec -T ${postgres_container_name}"
        else
            docker_command=
        fi

        # Wenn ein Docker-Befehl festgelegt wurde...
        if [[ -n "${docker_command}" ]]; then

            # Wechsle ins Hauptverzeichnis des Docker-Projekts
            cd "${project_dir}"

            # Sichern der PostgreSQL-Datenbank im Datensicherungsziel
            ${docker_command} pg_dump -U "${postgresql_user}" -d "${postgresql_db}" > "${backup_dir}/postgres-dump.sql"

            # Wechsle zurück ins Skriptverzeichnis
            cd "${script_dir}"

            # Prüfen, ob die Sicherung PostgreSQL-Datenbank erfolgreich war
            if [[ -s "${backup_dir}/postgres-dump.sql" ]]; then
                log " - Der Dump der PostgreSQL-Datenbank wurde in der Datei [ postgres-dump.sql ] gesichert."
            else
                log " - Beim Sichern des PostgreSQL-Datenbank-Dumps ist ein Fehler aufgetreten!"
            fi

            # Variable des Docker-Befehls leeren
            docker_command=
        else
            log " - Die Erstellung eines Dumps der PostgreSQL-Datenbank konnte nicht durchgeführt"
            log "   werden, da der Container aktuell nicht ausgeführt wird!"
        fi

        # Prüfen, ob es eine oder mehrere YAML-Dateien im Docker-Projektverzeichnis gibt
        yamlfiles=()
        for yaml in "${project_dir}"/*.yaml; do
            [[ -f ${yaml} ]] || continue
            yamlfiles+=("${yaml}")
        done

        # Falls ja, kopiere bzw. überschreibe die YAML-Datei(en) ins Datensicherungsziel
        if [[ "${#yamlfiles[@]}" -eq 0 ]]; then
            log " - Es wurde keine YAML-Datei gefunden."
        else
            for yamlfile in "${yamlfiles[@]}"; do
                cp -p -- "${yamlfile}" "${backup_dir}/"
                if [[ -s "${backup_dir}/${yamlfile##*/}" ]]; then
                    log " - Die YAML-Datei [ ${yamlfile##*/} ] wurde gesichert."
                else
                    log " - Beim Sichern der YAML-Datei [ ${yamlfile##*/} ] ist ein Fehler aufgetreten!"
                fi
            done
        fi

        # Prüfen, ob es eine oder mehrere ENV-Dateien im Docker-Projektverzeichnis gibt
        envfiles=()
        for env in "${project_dir}"/*.env; do
            [[ -f "${env}" ]] || continue
            envfiles+=("${env}")
        done

        # Falls ja, kopiere bzw. überschreibe die ENV-Datei(en) ins Datensicherungsziel
        if [[ "${#envfiles[@]}" -eq 0 ]]; then
            log " - Es wurde keine ENV-Datei gefunden."
        else
            for envfile in "${envfiles[@]}"; do
                cp -p -- "${envfile}" "${backup_dir}/"
                if [[ -s "${backup_dir}/${yamlfile##*/}" ]]; then
                    log " - Die ENV-Datei [ ${envfile##*/} ] wurde gesichert."
                else
                    log " - Beim Sichern der ENV-Datei [ ${envfile##*/} ] ist ein Fehler aufgetreten!"
                fi
            done
        fi

        # Passe Ordner- und Dateireche im Sicherungsziel an
        chown -R ${dir_user}:${dir_group} ${backup_dir}
        log " - Die Ordner- und Dateirechte im Datensicherungsziel wurden auf [ ${dir_user}:${dir_group} ] gesetzt."

        # Backup-Verzeichnisse löschen, die älter sind als ${version_history} Tage (nicht rekursiv)
        if [[ "${version_history}" =~ ^[1-9][0-9]*$ ]]; then
            if find "${backup_dir%/*}" -maxdepth 1 -mindepth 1 -type d -mtime +"${version_history}" -print -quit | grep -q .; then
                log " - Versionsstände, die älter als [ ${version_history} ] Tag(e) sind, wurden gelöscht."
                find "${backup_dir%/*}" -maxdepth 1 -mindepth 1 -type d -mtime +"${version_history}" -exec rm -rf {} +
            fi
        fi

        log ""
        log "${hr}"
    else
        log " - Das ${project_container_name} Verzeichnis oder die Docker-Compose Datei wurde nicht gefunden."
        log ""
        log "${hr}"
    fi
fi
