#!/bin/bash

LOG_FILE="/home/Dash_installation_process.log"
CHECKPOINT_FILE="/home/Dash_installation_checkpoint"

exec > >(tee -a "$LOG_FILE") 2>&1

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

set_checkpoint() {
    echo "$1" > "$CHECKPOINT_FILE"
}

get_checkpoint() {
    if [ -f "$CHECKPOINT_FILE" ]; then
        cat "$CHECKPOINT_FILE"
    else
        echo "START"
    fi
}

if [ "$1" == "--reset" ]; then
    log "Resetowanie punktu kontrolnego."
    rm -f "$CHECKPOINT_FILE"
fi

check_internet() {
    if ! ping -c 1 google.com &> /dev/null; then
        log "Brak połączenia z Internetem. Sprawdź swoje ustawienia sieciowe." >&2
        exit 1
    fi
}

retry_command() {
    local command="$1"
    local max_retries=3
    local count=1
    local success=0

    while [ $count -le $max_retries ]; do
        if eval "$command"; then
            success=1
            break
        else
            log "Próba $count/$max_retries nie powiodła się. Ponawiam próbę..."
            sleep 5
        fi
        ((count++))
    done

    if [ $success -eq 0 ]; then
        log "Nie udało się wykonać operacji po $max_retries próbach. Zatrzymanie skryptu." >&2
        exit 1
    fi
}

CHECKPOINT=$(get_checkpoint)
log "Rozpoczęcie procesu od punktu kontrolnego: $CHECKPOINT"

if [ "$CHECKPOINT" == "START" ]; then
    log "Sprawdzanie połączenia z Internetem."
    check_internet
    log "Połączenie z Internetem jest aktywne."
    set_checkpoint "INSTALL_RSYNC"
    CHECKPOINT="INSTALL_RSYNC"
fi

if [ "$CHECKPOINT" == "INSTALL_RSYNC" ]; then
    log "Sprawdzanie i instalacja rsync, jeśli jest wymagane."
    if ! command -v rsync &> /dev/null; then
        retry_command "sudo apt-get update"
        retry_command "sudo apt-get install rsync -y"
    fi
    set_checkpoint "CLONE_REPO"
    CHECKPOINT="CLONE_REPO"
fi

if [ "$CHECKPOINT" == "CLONE_REPO" ]; then
    TEMP_DIR=$(mktemp -d)
    retry_command "git clone https://github.com/SpurtechEngineering/Dash_installation $TEMP_DIR"
    rsync -a "$TEMP_DIR/" /
    rm -rf "$TEMP_DIR"
    set_checkpoint "INSTALL_DEB"
    CHECKPOINT="INSTALL_DEB"
fi

if [ "$CHECKPOINT" == "INSTALL_DEB" ]; then
    DEB_FILE=$(find /home -type f -name "*realdash*.deb" | head -n 1)
    if [ -n "$DEB_FILE" ]; then
        retry_command "sudo dpkg -i '$DEB_FILE'"
        retry_command "sudo apt-get -f install -y"
        retry_command "sudo dpkg -i '$DEB_FILE'"
        set_checkpoint "ADD_AUTOSTART"
        CHECKPOINT="ADD_AUTOSTART"
    fi
fi

if [ "$CHECKPOINT" == "ADD_AUTOSTART" ]; then
    AUTOSTART_FILE="/etc/systemd/system/realdash.service"
    sudo bash -c "cat <<EOT > $AUTOSTART_FILE
[Unit]
Description=Automatyczne uruchamianie RealDash
After=network.target

[Service]
ExecStart=/usr/bin/realdash
Restart=always
User=root
WorkingDirectory=/
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=realdash

[Install]
WantedBy=multi-user.target
EOT"

    sudo systemctl daemon-reload
    sudo systemctl enable realdash.service
    sudo systemctl start realdash.service

    set_checkpoint "ADD_CAN_SUPPORT"
    CHECKPOINT="ADD_CAN_SUPPORT"
fi

if [ "$CHECKPOINT" == "ADD_CAN_SUPPORT" ]; then
    log "Instalacja pakietu can-utils."
    retry_command "sudo apt-get install -y can-utils"

    retry_command "sudo dtoverlay mcp2515-can0,oscillator=16000000,interrupt=25"
    retry_command "sudo dtoverlay spi-bcm2835-overlay"

    log "Tworzenie pliku konfiguracyjnego CAN."
    CONFIG_FILE="/home/dietpi/can_config.conf"
    echo "BAUDRATE=1000000" > "$CONFIG_FILE"
    sudo chown dietpi:dietpi "$CONFIG_FILE"
    sudo chmod 644 "$CONFIG_FILE"

    set_checkpoint "ENABLE_CAN_STARTUP"
    CHECKPOINT="ENABLE_CAN_STARTUP"
fi

if [ "$CHECKPOINT" == "ENABLE_CAN_STARTUP" ]; then
    SERVICE_FILE="/etc/systemd/system/monitor_can.service"
    sudo bash -c "cat <<EOT > $SERVICE_FILE
[Unit]
Description=Monitorowanie zmian baudrate dla magistrali CAN
After=network.target

[Service]
ExecStart=/home/dietpi/monitor_can_baudrate.sh
Restart=always
User=root
WorkingDirectory=/
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=monitor_can

[Install]
WantedBy=multi-user.target
EOT"

    sudo systemctl daemon-reload
    sudo systemctl enable monitor_can.service
    sudo systemctl start monitor_can.service

    set_checkpoint "FINISH_CAN_SETUP"
    CHECKPOINT="FINISH_CAN_SETUP"
fi

if [ "$CHECKPOINT" == "FINISH_CAN_SETUP" ]; then
    log "Instalacja magistrali CAN zakończona sukcesem!"
    rm -f "$CHECKPOINT_FILE"
	set_checkpoint "CONFIGURE_CURSOR_HIDE"
    CHECKPOINT="CONFIGURE_CURSOR_HIDE"
fi

# Ukrywanie kursora po zadanym czasie
if [ "$CHECKPOINT" == "CONFIGURE_CURSOR_HIDE" ]; then
    log "Konfiguracja ukrywania kursora po zadanym czasie."

    CONFIG_FILE="/home/dietpi/hide_cursor_config"
    DEFAULT_HIDE_TIME=10

    if [ ! -f "$CONFIG_FILE" ]; then
        echo "$DEFAULT_HIDE_TIME" > "$CONFIG_FILE"
    fi

    sudo chown dietpi:dietpi "$CONFIG_FILE"
    sudo chmod 644 "$CONFIG_FILE"

    HIDE_CURSOR_SCRIPT="/home/dietpi/hide_cursor.sh"
    sudo bash -c "cat <<EOT > $HIDE_CURSOR_SCRIPT
#!/bin/bash

CONFIG_FILE='/home/dietpi/hide_cursor_config'
DEFAULT_HIDE_TIME=10

if [ -f \"\$CONFIG_FILE\" ]; then
    HIDE_TIME=\$(cat \"\$CONFIG_FILE\")
else
    HIDE_TIME=\$DEFAULT_HIDE_TIME
fi

while true; do
    sleep \$HIDE_TIME
    DISPLAY=\$(echo \$DISPLAY)
    if [ -n \"\$DISPLAY\" ]; then
        xdotool mousemove 9999 9999
    fi
done
EOT"

    sudo chmod +x "$HIDE_CURSOR_SCRIPT"

    SERVICE_FILE="/etc/systemd/system/hide_cursor.service"
    sudo bash -c "cat <<EOT > $SERVICE_FILE
[Unit]
Description=Ukrywanie kursora po zadanym czasie
After=graphical.target

[Service]
ExecStart=/home/dietpi/hide_cursor.sh
Restart=always
User=dietpi
WorkingDirectory=/home/dietpi
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=hide_cursor

[Install]
WantedBy=multi-user.target
EOT"

    sudo systemctl daemon-reload
    sudo systemctl enable hide_cursor.service
    sudo systemctl start hide_cursor.service

    log "Konfiguracja ukrywania kursora zakończona."
    set_checkpoint "CONFIGURE_ACCESS"
    CHECKPOINT="CONFIGURE_ACCESS"
fi

if [ "$CHECKPOINT" == "CONFIGURE_ACCESS" ]; then
    log "Ograniczanie dostępu użytkownika dietpi do wybranych plików."
    sudo chown dietpi:dietpi /home/dietpi/{can_config.conf,hide_cursor_config,lightShiftFreq,tachColor}
    sudo chmod 644 /home/dietpi/{can_config.conf,hide_cursor_config,lightShiftFreq,tachColor}

    log "Konfiguracja zakończona. Wszystkie pliki autostartu powinny działać przy starcie systemu z zalogowanym użytkownikiem dietpi."
    set_checkpoint "CONFIGURE_AUTOLOGIN"
    CHECKPOINT="CONFIGURE_AUTOLOGIN"
fi

if [ "$CHECKPOINT" == "CONFIGURE_AUTOLOGIN" ]; then
    log "Konfiguracja automatycznego logowania na użytkownika dietpi."

    AUTLOGIN_SERVICE="/etc/systemd/system/getty@tty1.service.d/autologin.conf"

    sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
    sudo bash -c "cat <<EOT > $AUTLOGIN_SERVICE
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin dietpi --noclear %I \$TERM
EOT"

    sudo systemctl daemon-reexec
    log "Automatyczne logowanie na dietpi skonfigurowane pomyślnie."
    set_checkpoint "INTERNET CONNECTION DISABLING"
    CHECKPOINT="INTERNET CONNECTION DISABLING"
fi

if [ "$CHECKPOINT" == "INTERNET_CONNECTION_DISABLING" ]; then
    log "Wyłączanie sprawdzania połączenia z Internetem podczas uruchamiania systemu."
    
    CONFIG_FILE="/boot/dietpi.txt"
    if grep -q "AUTO_SETUP_BOOT_WAIT_FOR_NETWORK" "$CONFIG_FILE"; then
        sed -i 's/^AUTO_SETUP_BOOT_WAIT_FOR_NETWORK=.*/AUTO_SETUP_BOOT_WAIT_FOR_NETWORK=0/' "$CONFIG_FILE"
    else
        echo "AUTO_SETUP_BOOT_WAIT_FOR_NETWORK=0" >> "$CONFIG_FILE"
    fi
    
    log "Wyłączono oczekiwanie na połączenie z siecią."
    
    set_checkpoint "RESTART_DEVICE"
    CHECKPOINT="RESTART_DEVICE"
fi

if [ "$CHECKPOINT" == "RESTART_DEVICE" ]; then
    log "Konfiguracja zakończona. System zostanie teraz uruchomiony ponownie."

    log "Restart systemu za 5 sekund..."
    for i in {5..1}; do
        log "Restart za $i sekund..."
        sleep 1  # Dodanie opóźnienia dla lepszej czytelności komunikatów
    done

    log "Restartowanie systemu teraz!"
    sleep 2
    sudo reboot
fi