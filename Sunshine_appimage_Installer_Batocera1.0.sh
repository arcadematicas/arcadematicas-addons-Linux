#!/bin/bash

set -e

INSTALL_DIR="/userdata/system/pro"
STABLE_DIR="$INSTALL_DIR/sunshine_stable"
BETA_DIR="$INSTALL_DIR/sunshine_beta"
SERVICE_FILE="/userdata/system/services/sunshine"
LOG_FILE="/userdata/system/logs/sunshine.log"
PID_FILE="$INSTALL_DIR/sunshine.pid"  # Usamos un directorio accesible

function stop_existing() {
    echo "Deteniendo cualquier instancia de Sunshine..." | tee -a "$LOG_FILE"
    pkill -f sunshine || true
}

function select_version() {
    echo "¿Qué versión de Sunshine quieres instalar?"
    echo "1) Estable"
    echo "2) Beta"
    read -p "Selecciona una opción [1-2]: " choice
    case $choice in
        1) VERSION="stable" ;;
        2) VERSION="beta" ;;
        *) echo "Opción no válida. Abortando."; exit 1 ;;
    esac
}

function get_latest_url() {
    local version_filter="$1"
    local json_url="https://api.github.com/repos/LizardByte/Sunshine/releases"
    local url=$(curl -s "$json_url" | jq -r ".[] | select(.prerelease == $version_filter) | .assets[] | select(.name | endswith(\"AppImage\")) | .browser_download_url" | head -n 1)
    echo "$url"
}

function install_sunshine() {
    stop_existing
    select_version

    if [ "$VERSION" == "stable" ]; then
        DOWNLOAD_URL=$(get_latest_url "false")
        TARGET_DIR="$STABLE_DIR"
    else
        DOWNLOAD_URL=$(get_latest_url "true")
        TARGET_DIR="$BETA_DIR"
    fi

    if [ -z "$DOWNLOAD_URL" ]; then
        echo "Error: No se encontró una URL de descarga para la versión seleccionada." | tee -a "$LOG_FILE"
        exit 1
    fi

    echo "Descargando Sunshine desde: $DOWNLOAD_URL" | tee -a "$LOG_FILE"
    mkdir -p "$TARGET_DIR"
    curl -L "$DOWNLOAD_URL" -o "$TARGET_DIR/sunshine.AppImage"
    chmod +x "$TARGET_DIR/sunshine.AppImage"

    # Asegurarse de que la carpeta para el PID exista
    mkdir -p "$INSTALL_DIR"

    # Arrancar Sunshine en segundo plano (desacoplado del terminal) usando nohup
    echo "Arrancando Sunshine en segundo plano..." | tee -a "$LOG_FILE"
    nohup "$TARGET_DIR/sunshine.AppImage" &>/dev/null &
    
    # Esperar a que se inicie y que se cree el archivo PID
    echo "Esperando a que Sunshine genere el archivo PID..." | tee -a "$LOG_FILE"
    COUNTER=0
    while [ ! -f "$PID_FILE" ] && [ $COUNTER -lt 30 ]; do
        sleep 1
        ((COUNTER++))
    done

    if [ ! -f "$PID_FILE" ]; then
        # Si no se generó, intentamos obtener el PID manualmente
        SUNSHINE_PID=$(pgrep -f "sunshine.AppImage" | head -n 1)
        if [ -n "$SUNSHINE_PID" ]; then
            echo "$SUNSHINE_PID" > "$PID_FILE"
            echo "Archivo PID creado manualmente: $SUNSHINE_PID" | tee -a "$LOG_FILE"
        else
            echo "Error: No se pudo obtener el PID de Sunshine." | tee -a "$LOG_FILE"
            exit 1
        fi
    fi

    SUNSHINE_PID=$(cat "$PID_FILE")
    if [ -n "$SUNSHINE_PID" ]; then
        echo "PID de Sunshine: $SUNSHINE_PID" | tee -a "$LOG_FILE"
    else
        echo "Error: No se pudo obtener el PID de Sunshine." | tee -a "$LOG_FILE"
        exit 1
    fi

    # Generar el servicio sin incluir comillas literales en la ruta del PID
    echo "Configurando el servicio..." | tee -a "$LOG_FILE"
    cat <<EOF > "$SERVICE_FILE"
#!/bin/bash

start() {
    echo "Iniciando Sunshine..." | tee -a $LOG_FILE
    nohup "$TARGET_DIR/sunshine.AppImage" &>/dev/null &
    echo \$! > $PID_FILE
}

stop() {
    if [ -f $PID_FILE ]; then
        PID=\$(cat $PID_FILE)
        if kill -0 "\$PID" 2>/dev/null; then
            echo "Deteniendo Sunshine (PID: \$PID)..." | tee -a $LOG_FILE
            kill "\$PID" && rm -f $PID_FILE
        else
            echo "PID no válido, eliminando archivo PID." | tee -a $LOG_FILE
            rm -f $PID_FILE
        fi
    else
        echo "Sunshine no está en ejecución." | tee -a $LOG_FILE
    fi
}

case "\$1" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    restart)
        stop
        sleep 2
        start
        ;;
    *)
        echo "Uso: \$0 {start|stop|restart}" | tee -a $LOG_FILE
        exit 1
        ;;
esac
EOF

    chmod +x "$SERVICE_FILE"
    echo "Instalación completada. Sunshine está listo para ejecutarse." | tee -a "$LOG_FILE"
# Mensaje final con instrucciones
echo ""
echo "¡Felicidades! Sunshine se ha instalado y está funcionando correctamente."
echo "Puedes acceder a la interfaz de usuario de Sunshine abriendo un navegador web y navegando a:"
echo "https://localhost:47990"
echo "Desde allí podrás configurar y personalizar las opciones de Sunshine."

echo ""
echo "Para jugar y disfrutar del streaming, descarga Moonshine en tu dispositivo móvil o SteamDeck:"
echo "https://github.com/LizardByte/Moonshine/releases"

echo ""
echo "Este script fue creado por ChatGPT y Arcadematicas para facilitar la instalación y configuración de Sunshine, no te pierdas los videos de youtube y suscribete perra!."

echo ""
echo "¡Disfruta del streaming de tus juegos en tu dispositivo favorito!"
}

install_sunshine

