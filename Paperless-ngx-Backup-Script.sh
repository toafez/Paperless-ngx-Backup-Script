#!/bin/bash
# Filename: Paperless-ngx-Backup-Script.sh - coded in utf-8
version="1.0-000"


#             Backupskript für Paperless-ngx 
#    Copyright (C) 2025 by tommes (toafez) | MIT License


# --------------------------------------------------------------
# Verbindliche, benutzerspezifische Angaben
# --------------------------------------------------------------

# Angaben zur Benutzer- und Gruppenzugehörigkeit
username="BENUTZERNAME"
groupname="admin"

# Angaben zum lokalen Datensicherungsziel
backup_dir="/PFAD/ZUM/DATENSICHERUNGSZIEL"

# Angaben zu Paperless-ngx
paperless_dir="/PFAD/ZUM/PAPERLESS-NGX-VERZEICHNIS"
paperless_container="Paperless-ngx"
paperless_service="webserver"

# Angaben zur PostgreSQL-Datenbank
postgresql_container="Paperless-ngx-PostgreSQL"
postgresql_service="db"
postgresql_user="paperless"
postgresql_db="paperless"

# --------------------------------------------------------------
# Optionale, benutzerspezifische Angaben
# --------------------------------------------------------------

# Pfad und Dateiname der Original Paplerless-ngx YAML-Datei (Docker-Compose)
yamlfile=("${paperless_dir}"/docker-compose.yaml)

# Pfad und Dateiname der Original Paperless-ngx ENV-Datei (Environment-Attribute)
envfile=("${paperless_dir}"/*.env)

# Pfad und Dateiname der PostgreSQL Dump-Backup-Datei 
dumpfile=("${backup_dir}"/postgres-dump.sql)

# Pfad und Dateiname der Protokolldatei
logfile=("${backup_dir}"/backup-protocol.log)

# --------------------------------------------------------------
# Rock ’n’ Roll...
# --------------------------------------------------------------

# Skript sofort beenden wenn Fehlerstatus ungleich null ist
set -e

# Rückgabewert auf den ersten fehlerhaften Befehl innerhalb der Pipeline setzen
set -o pipefail

# Falls noch nicht vorhanden, Datensicherungsziel erstellen
[ ! -d "${backup_dir}" ] &&  mkdir -p "${backup_dir}"

if [ -d "${backup_dir}" ]; then

    # Aktuelles Datum
    datestamp() {
        date +"%d.%m.%Y"
    }

    # Aktuelle Uhrzeit
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

    echo "${hr}" | tee -a "${logfile}"
    echo "Paperless-ngx Datensicherungsprotokoll vom $(datestamp) um $(timestamp) Uhr" | tee -a "${logfile}"
    echo " - Datensicherungsziel: ${backup_dir}" | tee -a "${logfile}"
    echo "${hr}" | tee -a "${logfile}"
    echo "" | tee -a "${logfile}"

    if [ -d ${paperless_dir} ]; then

        # Prüfen, ob der Paperless-ngx-Container läuft
        if [[ $(docker inspect -f '{{.State.Running}}' ${paperless_container} 2>/dev/null) ]]; then

            echo "Die integrierte Exportfunktion von Paperless-ngx wird ausgeführt...." | tee -a "${logfile}"

            # Sichern aller Dokumente in den Paperless-NGX-Exportordner (-d entfernt zwischenzeitlich gelöschte Dateien aus dem Exportordner)
            docker compose -f "${yamlfile}" exec -T "${paperless_service}" document_exporter ../export -d

            # Prüfen, ob Dokumente im Paperless-NGX-Exportordner vorhanden sind
            if [ -n "$(ls -A ${paperless_dir}/export)" ]; then

                # Sichern aller exportierten Dokumente aus dem Paperless-NGX-Exportordner ins Datensicherungsziel
                rsync -a --delete ${paperless_dir}/export ${backup_dir}

                # Prüfen, ob Dokumente im Datensicherungsziel vorhanden sind
                if [ -d "${backup_dir}/export" ]; then
                    echo " - Der Paperless-NGX-Exportordner wurde gesichert." | tee -a "${logfile}"
                else
                    echo " - Die Sicherung des Paperless-NGX-Exportordners war nicht möglich." | tee -a "${logfile}"
                fi
            else
                echo " - Die Bereitstellung der Dokumente im Paperless-NGX-Exportordner war nicht möglich." | tee -a "${logfile}"
            fi
        else
            echo " - Die Sicherung des Paperless-NGX-Exportordners kann nicht durchgeführt werden, da der  " | tee -a "${logfile}"
            echo "   entsprechende [ ${paperless_container} ] Container aktuell nicht ausgeführt wird!" | tee -a "${logfile}"
        fi

        # Prüfen, ob der PostgreSQL-Container läuft
        if [[ $(docker inspect -f '{{.State.Running}}' ${postgresql_container} 2>/dev/null) ]]; then

            # Sichern der PostgreSQL-Datenbank im Datensicherungsziel
            docker compose -f "${yamlfile}" exec -T "${postgresql_service}" pg_dump -U "${postgresql_user}" -d "${postgresql_db}" > "${dumpfile}"

            # Prüfen, ob die Sicherung PostgreSQL-Datenbank erfolgreich war
            if [ -f "${dumpfile}" ] || [ -s "${dumpfile}" ]; then
                echo " - Die PostgreSQL-Datenbank wurde gesichert." | tee -a "${logfile}"
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
            backup_yamlfile=("${backup_dir}"/*.yaml)
            
            # Prüfen, ob die YAML-Datei im Datensicherungsziel angekommen ist
            if [ -f "${backup_yamlfile}" ] || [ -s "${backup_yamlfile}" ]; then
                echo " - Die YAML-Datei wurde gesichert." | tee -a "${logfile}"
            else
                echo " - Die Sicherung der YAML-Datei konnte nicht durchgeführt werden." | tee -a "${logfile}"
            fi
        fi

        # Prüfen, ob es eine ENV-Datei im Paperless-ngx Verzeichnis gibt
        if [ -f "${envfile}" ]; then

            # Sichern der ENV-Datei
            rsync -a --delete "${envfile}" "${backup_dir}/"
            backup_envfile=("${backup_dir}"/*.env)
            
            # Prüfen, ob die ENV-Datei im Datensicherungsziel angekommen ist
            if [ -f "${backup_envfile}" ] || [ -s "${backup_envfile}" ]; then
                echo " - Die ENV-Datei wurde gesichert." | tee -a "${logfile}"
            else
                echo " - Die Sicherung der ENV-Datei konnte nicht durchgeführt werden." | tee -a "${logfile}"
            fi
        fi

        # Passe Ordner- und Dateireche im Sicherungsziel an
        chown -R ${username}:${groupname} ${backup_dir}
        echo " - Die Ordner- und Dateirechte im Sicherungsziel wurden auf [ ${username}:${groupname} ] gesetzt." | tee -a "${logfile}"
        echo "" | tee -a "${logfile}"
        echo "${hr}" | tee -a "${logfile}"
    else
        echo " - Das Paperless-ngx Verzeichnis oder die Docker-Compose Datei wurde nicht gefunden." | tee -a "${logfile}"
        echo "" | tee -a "${logfile}"
        echo "${hr}" | tee -a "${logfile}"
    fi
fi
