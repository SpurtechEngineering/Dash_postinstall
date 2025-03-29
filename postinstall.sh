#!/bin/bash

LOG_FILE="/home/Dash_installation_process.log"
CHECKPOINT_FILE="/home/Dash_installation_checkpoint"

# Przekierowanie całego procesu do pliku logu
exec > >(tee -a "$LOG_FILE") 2>&1

# Funkcja do zapisywania logów
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Funkcja do zapisywania punktu kontrolnego
set_checkpoint() {
    echo "$1" > "$CHECKPOINT_FILE"
}

# Funkcja do odczytania punktu kontrolnego
get_checkpoint() {
    if [ -f "$CHECKPOINT_FILE" ]; then
        cat "$CHECKPOINT_FILE"
    else
        echo "START"
    fi
}

# Sprawdzenie dostępności Internetu
check_internet() {
    if ! ping -c 1 google.com &> /dev/null; then
        log "Brak połączenia z Internetem. Sprawdź swoje ustawienia sieciowe." >&2
        exit 1
    fi
}

# Pobranie ostatniego punktu kontrolnego
CHECKPOINT=$(get_checkpoint)
log "Rozpoczęcie procesu od punktu kontrolnego: $CHECKPOINT"

# Sprawdzanie dostępności Internetu na początku skryptu
if [ "$CHECKPOINT" == "START" ]; then
    log "Sprawdzanie połączenia z Internetem."
    check_internet
    log "Połączenie z Internetem jest aktywne."
    set_checkpoint "INSTALL_RSYNC"
fi

# Sprawdzanie i instalacja rsync, jeśli nie jest zainstalowany
if [ "$CHECKPOINT" == "INSTALL_RSYNC" ]; then
    log "Sprawdzanie i instalacja rsync, jeśli jest wymagane."
    if ! command -v rsync &> /dev/null; then
        log "rsync nie jest zainstalowany. Rozpoczynanie instalacji."
        sudo apt-get update
        sudo apt-get install rsync -y
        if [ $? -eq 0 ]; then
            log "rsync został pomyślnie zainstalowany."
        else
            log "Błąd podczas instalacji rsync." >&2
            exit 1
        fi
    else
        log "rsync jest już zainstalowany. Kontynuowanie procesu."
    fi
    set_checkpoint "CLONE_REPO"
fi

# Klonowanie repozytorium GitHub
if [ "$CHECKPOINT" == "CLONE_REPO" ]; then
    log "Tworzenie tymczasowego folderu do pobrania repozytorium."
    TEMP_DIR=$(mktemp -d)
    log "Klonowanie repozytorium z GitHub."
    git clone https://github.com/SpurtechEngineering/Dash_installation "$TEMP_DIR"
    if [ $? -eq 0 ]; then
        log "Pobieranie repozytorium zakończone sukcesem."
        set_checkpoint "MOVE_FILES"
    else
        log "Błąd podczas pobierania repozytorium." >&2
        exit 1
    fi
fi

# Przenoszenie plików
if [ "$CHECKPOINT" == "MOVE_FILES" ]; then
    log "Przenoszenie pobranych plików do katalogu głównego (/)."
    TARGET_DIR="/"
    rsync -a "$TEMP_DIR/" "$TARGET_DIR/"
    if [ $? -eq 0 ]; then
        log "Pliki zostały przeniesione do katalogu głównego."
        rm -rf "$TEMP_DIR"
        set_checkpoint "INSTALL_DEB"
    else
        log "Błąd podczas przenoszenia plików." >&2
        exit 1
    fi
fi

# Instalacja pliku .deb
if [ "$CHECKPOINT" == "INSTALL_DEB" ]; then
    log "Wyszukiwanie pliku .deb zawierającego 'realdash' w nazwie."
    DEB_FILE=$(find / -type f -name "*realdash*.deb" 2>/dev/null | head -n 1)
    if [ -n "$DEB_FILE" ]; then
        log "Znaleziono plik .deb: $DEB_FILE. Rozpoczynanie instalacji."
        sudo dpkg -i "$DEB_FILE"
        if [ $? -eq 0 ]; then
            log "Instalacja pliku .deb zakończona sukcesem."
            log "Rozpoczynanie instalacji brakujących zależności."
            sudo apt-get -f install -y
            if [ $? -eq 0 ]; then
                log "Instalacja brakujących zależności zakończona sukcesem."
                set_checkpoint "FINISH"
            else
                log "Błąd podczas instalacji brakujących zależności." >&2
                exit 1
            fi
        else
            log "Błąd podczas instalacji pliku .deb." >&2
            exit 1
        fi
    else
        log "Nie znaleziono pliku .deb zawierającego 'realdash' w nazwie." >&2
        exit 1
    fi
fi

# Zakończenie procesu
if [ "$CHECKPOINT" == "FINISH" ]; then
    log "Proces instalacji zakończony pomyślnie!"
    rm -f "$CHECKPOINT_FILE"
    exit 0
fi