#!/bin/bash

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

# Przeniesienie pobranych plików do folderu docelowego
TARGET_DIR="/home/Dash_installation"
mv "$TEMP_DIR"/* "$TARGET_DIR"

# Sprawdzenie, czy operacja przenoszenia się powiodła
if [ $? -eq 0 ]; then
    echo "Pliki zostały przeniesione do folderu $TARGET_DIR."
else
    echo "Błąd podczas przenoszenia plików." >&2
    exit 1
fi

# Usunięcie tymczasowego folderu
rm -rf "$TEMP_DIR"

# Instalacja pliku .deb
DEB_FILE="/home/Dash_installation/*.deb"
if [ -f "$DEB_FILE" ]; then
    sudo dpkg -i "$DEB_FILE"
    
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