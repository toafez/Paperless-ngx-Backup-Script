#!/bin/bash
# Filename: Paperless-ngx-Backup-Script.sh - coded in utf-8
version="1.0-100"


#             Backupskript für Paperless-ngx 
#    Copyright (C) 2025 by tommes (toafez) | MIT License


# --------------------------------------------------------------
# Verbindliche, benutzerspezifische Angaben
# --------------------------------------------------------------

# Angaben zum lokalen Datensicherungsziel
backup_dir="/Pfad/zum/Datensicherungsziel"

# Angaben zu Paperless-ngx
paperless_dir="/Pfad/zum/Paperless-ngx-Verzeichnis"
paperless_container="Paperless-ngx"

# Angaben zur PostgreSQL-Datenbank
postgresql_container="Paperless-ngx-PostgreSQL"
postgresql_user="paperless"
postgresql_db="paperless"

# --------------------------------------------------------------
# Optionale, benutzerspezifische Angaben
# --------------------------------------------------------------

# Pfad und Dateiname der Paplerless-ngx YAML-Datei (Docker-Compose)
yamlfile="${paperless_dir}/docker-compose.yaml"

# Pfad und Dateiname der Paperless-ngx ENV-Datei (Environment-Attribute)
envfile="${paperless_dir}/paperless.env"

# Pfad und Dateiname des zu sichernden PostgreSQL-Dumps
dumpfile="${backup_dir}/postgres-dump.sql"

# Pfad und Dateiname der Protokolldatei
logfile="${backup_dir}/backup-protocol.log"

# --------------------------------------------------------------
# Rock ’n’ Roll...
# --------------------------------------------------------------

# Skript sofort beenden wenn Fehlerstatus ungleich null ist
set -e

# Rückgabewert auf den ersten fehlerhaften Befehl innerhalb der Pipeline setzen
set -o pipefail

# Variable für den Verzeichnisvergleich zurücksetzen
identical_dir=

# Absoluten Pfad des Shell-Skripts ermitteln
script_dir="$(dirname "$(readlink -fn "$0")")"

# Falls noch nicht vorhanden, Datensicherungsziel erstellen
[ ! -d "${backup_dir}" ] &&  mkdir -p "${backup_dir}"

# Falls das Datensicherungsziel exisitiert...
if [ -d "${backup_dir}" ]; then

    # Funktion: Aktuelles Datum ermitteln
    datestamp() {
        date +"%d.%m.%Y"
    }

    # Funktion: Aktuelle Uhrzeit ermitteln
    timestamp() {
        date +"%H:%M:%S"
    }

    # Falls vorhanden, Protokolldatei löschen. Andernfalls eine neue Protokolldatei erstellen.
    [ -f "${logfile}" ] && rm -f "${logfile}"
    [ ! -f "${logfile}" ] && touch "${logfile}"

    # Beginn des Protokolls...
    hr="---------------------------------------------------------------------------------------------------------"

    # Prüfen, ob das verwendete Skript aktuell ist oder ob ein Update auf GitHub verfügbar ist
    git_version=$(wget --no-check-certificate --timeout=60 --tries=1 -q -O- "https://raw.githubusercontent.com/toafez/Paperless-ngx-Backup-Script/refs/heads/main/Paperless-ngx-Backup-Script.sh" | grep ^version | cut -d '"' -f2)		
    if [ -n "${git_version}" ] && [ -n "${version}" ]; then
        if dpkg --compare-versions ${git_version} gt ${version}; then
            echo "${hr}" | tee -a "${logfile}" | tee -a "${logfile}"
            echo "WICHTIGER HINWEIS:" | tee -a "${logfile}"
            echo "Auf GitHub steht ein Update für dieses Skript zur Verfügung." | tee -a "${logfile}"
            echo "Bitte aktualisiere deine Version ${version} auf die neue Version ${git_version}." | tee -a "${logfile}"
            echo "Link: https://github.com/toafez/Paperless-ngx-Backup-Script" | tee -a "${logfile}"
            echo "${hr}" | tee -a "${logfile}" | tee -a "${logfile}"
            echo "" | tee -a "${logfile}" | tee -a "${logfile}"
        fi
    fi

    # Wenn das Hauptverzeichnis von Paperless-ngx existiert...
    if [ -d "${paperless_dir}" ]; then

        # Prüfen, welchem Benutzer das Verzeichnis gehört
        dir_user=$(stat -c '%U' "${paperless_dir}")

        # Prüfen, welcher Gruppe dieses Verzeichnis gehört
        dir_group=$(stat -c '%G' "${paperless_dir}")

        # Funktion: Wechsle ins Hauptverzeichnis von Paperless-ngx
        change_to_paperless_dir() {
            if [[ "${script_dir}" == "${paperless_dir}" ]]; then
                identical_dir="true"
            else
                identical_dir="false"
                cd "${paperless_dir}"
            fi
        }

        # Funktion: Wechsle zurück ins Skriptverzeichnis
        change_to_current_dir() {
            if [[ "${identical_dir}" == "false" ]]; then
                identical_dir=
                cd "${current_dir}"
            fi
        }

        echo "${hr}" | tee -a "${logfile}"
        echo "Paperless-ngx Datensicherungsprotokoll vom $(datestamp) um $(timestamp) Uhr" | tee -a "${logfile}"
        echo " - Datensicherungsziel: ${backup_dir}" | tee -a "${logfile}"
        echo "${hr}" | tee -a "${logfile}"
        echo "" | tee -a "${logfile}"

        # Prüfen, ob der Paperless-ngx-Container läuft
        if [[ $(docker inspect -f '{{.State.Running}}' ${paperless_container} 2>/dev/null) ]]; then

            # Wechsle ins Hauptverzeichnis von Paperless-ngx
            change_to_paperless_dir

            # Sichern aller Dokumente in das Paperless-NGX-Exportverzeichnis (-d entfernt zwischenzeitlich gelöschte Dateien aus dem Exportverzeichnis)
            echo "Die integrierte Exportfunktion von Paperless-ngx wird ausgeführt...." | tee -a "${logfile}"
            docker exec "${paperless_container}" document_exporter ../export -d

            # Wechsle zurück ins Skriptverzeichnis
            change_to_current_dir

            # Prüfen, ob Dokumente im Paperless-NGX-Exportverzeichnis vorhanden sind
            if [ -n "$(ls -A ${paperless_dir}/export)" ]; then

                # Sichern aller exportierten Dokumente aus dem Paperless-NGX-Exportverzeichnis ins Datensicherungsziel
                rsync -a --delete ${paperless_dir}/export ${backup_dir}

                # Prüfen, ob Dokumente im Datensicherungsziel vorhanden sind
                if [ -d "${backup_dir}/export" ]; then
                    echo " - Das Paperless-NGX-Exportverzeichnis [ /export ] wurde gesichert." | tee -a "${logfile}"
                else
                    echo " - Die Sicherung des Paperless-NGX-Exportverzeichnises war nicht möglich." | tee -a "${logfile}"
                fi
            else
                echo " - Die Bereitstellung der Dokumente im Paperless-NGX-Exportverzeichnis war nicht möglich." | tee -a "${logfile}"
            fi
        else
            echo " - Die Sicherung des Paperless-NGX-Exportverzeichnises kann nicht durchgeführt werden, da der  " | tee -a "${logfile}"
            echo "   entsprechende [ ${paperless_container} ] Container aktuell nicht ausgeführt wird!" | tee -a "${logfile}"
        fi

        # Prüfen, ob der PostgreSQL-Container läuft
        if [[ $(docker inspect -f '{{.State.Running}}' ${postgresql_container} 2>/dev/null) ]]; then

            # Wechsle ins Hauptverzeichnis von Paperless-ngx
            change_to_paperless_dir

            # Sichern der PostgreSQL-Datenbank im Datensicherungsziel
            docker exec "${postgresql_container}" pg_dump -U "${postgresql_user}" -d "${postgresql_db}" > "${dumpfile}"

            # Wechsle zurück ins Skriptverzeichnis
            change_to_current_dir

            # Prüfen, ob die Sicherung PostgreSQL-Datenbank erfolgreich war
            if [ -f "${dumpfile}" ] || [ -s "${dumpfile}" ]; then
                echo " - Die PostgreSQL-Datenbank wurde in der Datei [ ${dumpfile##*/} ] gesichert." | tee -a "${logfile}"
            else
                echo " - Die Sicherung der PostgreSQL-Datenbank war nicht möglich." | tee -a "${logfile}"
            fi
        else
            echo " - Die Sicherung der PostgreSQL-Datenbank kann nicht durchgeführt werden, da der  " | tee -a "${logfile}"
            echo "   entsprechende [ ${postgresql_container} ] Container aktuell nicht ausgeführt wird!" | tee -a "${logfile}"
        fi

        # Prüfen, ob es eine YAML-Datei im Paperless-ngx Verzeichnis gibt
        if [ -f "${yamlfile}" ]; then

            # Sichern der YAML-Datei
            rsync -a --delete "${yamlfile}" "${backup_dir}/"
            
            # Prüfen, ob die YAML-Datei im Datensicherungsziel angekommen ist
            if [ -f "${backup_dir}/${yamlfile##*/}" ] || [ -s "${backup_dir}/${yamlfile##*/}" ]; then
                echo " - Die YAML-Datei [ ${yamlfile##*/} ] wurde gesichert." | tee -a "${logfile}"
            else
                echo " - Die Sicherung der YAML-Datei [ ${yamlfile##*/} ] konnte nicht durchgeführt werden." | tee -a "${logfile}"
            fi
        fi

        # Prüfen, ob es eine ENV-Datei im Paperless-ngx Verzeichnis gibt
        if [ -f "${envfile}" ]; then

            # Sichern der ENV-Datei
            rsync -a --delete "${envfile}" "${backup_dir}/"
            
            # Prüfen, ob die ENV-Datei im Datensicherungsziel angekommen ist
            if [ -f "${backup_dir}/${envfile##*/}" ] || [ -s "${backup_dir}/${envfile##*/}" ]; then
                echo " - Die ENV-Datei [ ${envfile##*/} ] wurde gesichert." | tee -a "${logfile}"
            else
                echo " - Die Sicherung der ENV-Datei [ ${envfile##*/} ] konnte nicht durchgeführt werden." | tee -a "${logfile}"
            fi
        fi

        # Passe Ordner- und Dateireche im Sicherungsziel an
        chown -R ${dir_user}:${dir_group} ${backup_dir}
        echo " - Die Ordner- und Dateirechte im Datensicherungsziel wurden auf [ ${dir_user}:${dir_group} ] gesetzt." | tee -a "${logfile}"
        echo "" | tee -a "${logfile}"
        echo "${hr}" | tee -a "${logfile}"
    else
        echo " - Das Paperless-ngx Verzeichnis oder die Docker-Compose Datei wurde nicht gefunden." | tee -a "${logfile}"
        echo "" | tee -a "${logfile}"
        echo "${hr}" | tee -a "${logfile}"
    fi
fi
