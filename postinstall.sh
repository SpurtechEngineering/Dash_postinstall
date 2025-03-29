#!/bin/bash

# Instalacja rsync, jeśli nie jest zainstalowany
if ! command -v rsync &> /dev/null; then
    echo "Instalowanie rsync..."
    sudo apt-get update
    sudo apt-get install rsync -y
    if [ $? -eq 0 ]; then
        echo "rsync został pomyślnie zainstalowany."
    else
        echo "Błąd podczas instalacji rsync." >&2
        exit 1
    fi
fi

# Tworzenie tymczasowego folderu do pobrania repozytorium
TEMP_DIR=$(mktemp -d)

# Klonowanie repozytorium GitHub do tymczasowego folderu
git clone https://github.com/SpurtechEngineering/Dash_installation "$TEMP_DIR"

# Sprawdzenie, czy operacja klonowania się powiodła
if [ $? -eq 0 ]; then
    echo "Pobieranie repozytorium zakończone sukcesem."
else
    echo "Błąd podczas pobierania repozytorium." >&2
    exit 1
fi

# Przeniesienie pobranych plików do folderu docelowego z połączeniem istniejącej struktury
TARGET_DIR="/home/Dash_installation"

# Utworzenie folderu docelowego, jeśli nie istnieje
mkdir -p "$TARGET_DIR"

# Połączenie struktury plików za pomocą rsync
rsync -a "$TEMP_DIR/" "$TARGET_DIR/"

# Sprawdzenie, czy operacja rsync się powiodła
if [ $? -eq 0 ]; then
    echo "Pliki zostały połączone ze strukturą w folderze $TARGET_DIR."
else
    echo "Błąd podczas łączenia plików." >&2
    exit 1
fi

# Usunięcie tymczasowego folderu
rm -rf "$TEMP_DIR"

# Instalacja pliku .deb
DEB_FILE="$TARGET_DIR/*.deb"
if [ -f $DEB_FILE ]; then
    sudo dpkg -i $DEB_FILE
    
    # Sprawdzenie, czy operacja instalacji się powiodła
    if [ $? -eq 0 ]; then
        echo "Instalacja pliku .deb zakończona sukcesem."
        
        # Instalacja brakujących zależności
        sudo apt-get -f install -y
        
        if [ $? -eq 0 ]; then
            echo "Instalacja brakujących zależności zakończona sukcesem."
        else
            echo "Błąd podczas instalacji brakujących zależności." >&2
            exit 1
        fi
    else
        echo "Błąd podczas instalacji pliku .deb." >&2
        exit 1
    fi
else
    echo "Plik .deb nie istnieje w podanej lokalizacji: $DEB_FILE" >&2
    exit 1
fi