#!/usr/bin/env bash
# Idee von mir, Epiphanius H.G.H. Wenzel, Code von AI
# Das Skript kommt in ~/.local/share/nautilus/scripts/Als_Desktop_setzen.sh zu liegen; ausführbar machen nicht vergessen.
# Einen Ordner auswählen, im Kontextmenü Skripte/Als_Desktop_setzen.sh auswählen; zeigt dann den Inhalt des ausgewählten Ordners auf dem Desktop; wenn die selbe Aktion erneut auf einem Nicht-Ordner erfolgt, wird der ursprüngliche Desktopinhalt wieder hergestellt.

CONFIG_FILE="$HOME/.config/user-dirs.dirs"
BACKUP_FILE="$HOME/.config/user-dirs.dirs.bak"
EXTENSION_ID="ding@rastersoft.com"

# Funktion zum Neuladen der Desktop-Icons-Erweiterung
reload_desktop_extension() {
    # Prüfen, ob gnome-extensions installiert und DING aktiv ist
    if command -v gnome-extensions &> /dev/null; then
        if gnome-extensions list --enabled | grep -q "$EXTENSION_ID"; then
            # Kurz aus- und wieder einschalten erzwingt das Neuladen des Desktop-Pfads
            gnome-extensions disable "$EXTENSION_ID"
            sleep 0.5
            gnome-extensions enable "$EXTENSION_ID"
        fi
    fi
    # Sicherheits-Fallback: Nautilus-Neustart
    nautilus -q
}

# 1. Option: Wiederherstellung triggern
if [ "$1" == "--restore" ]; then
    if [ -f "$BACKUP_FILE" ]; then
        cp "$BACKUP_FILE" "$CONFIG_FILE"
        xdg-user-dirs-update
        reload_desktop_extension
        zenity --info --text="Der ursprüngliche Desktop-Ordner wurde wiederhergestellt." --title="Erfolg"
    else
        # Fallback auf Standard-Ordner
        xdg-user-dirs-update --set DESKTOP "$HOME/Schreibtisch"
        reload_desktop_extension
        zenity --warning --text="Kein Backup gefunden. Standard-Ordner (~/Schreibtisch) wurde gesetzt." --title="Hinweis"
    fi
    exit 0
fi

# 2. Ausgewählten Ordner aus Nautilus auslesen
SELECTED_PATH=$(echo "$NAUTILUS_SCRIPT_SELECTED_FILE_PATHS" | head -n 1)

# 3. Wenn kein Ordner gewählt wurde -> Nach Wiederherstellung fragen
if [ -z "$SELECTED_PATH" ] || [ ! -d "$SELECTED_PATH" ]; then
    if zenity --question --text="Du hast keinen Ordner ausgewählt.\nMöchtest du den ursprünglichen Desktop-Ordner wiederherstellen?" --title="Desktop zurücksetzen" --ok-label="Wiederherstellen" --cancel-label="Abbrechen"; then
        "$0" --restore
    fi
    exit 0
fi

# 4. Ordner als Desktop setzen & Backup erstellen
if [ ! -f "$BACKUP_FILE" ]; then
    cp "$CONFIG_FILE" "$BACKUP_FILE"
fi

xdg-user-dirs-update --set DESKTOP "$SELECTED_PATH"
reload_desktop_extension

zenity --info --text="Der Desktop-Inhalt wurde erfolgreich geändert zu:\n$SELECTED_PATH" --title="Erfolg"

