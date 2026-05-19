#!/usr/bin/env bash
set -euo pipefail

# ─── colors ──────────────────────────────────────────────────────────────────
if [ -t 1 ] && command -v tput &>/dev/null && tput colors &>/dev/null; then
    BOLD=$(tput bold); DIM=$(tput dim); RESET=$(tput sgr0)
    RED=$(tput setaf 1); GREEN=$(tput setaf 2); YELLOW=$(tput setaf 3)
    CYAN=$(tput setaf 6); WHITE=$(tput setaf 7)
else
    BOLD=''; DIM=''; RESET=''; RED=''; GREEN=''; YELLOW=''; CYAN=''; WHITE=''
fi

# ─── helpers ─────────────────────────────────────────────────────────────────
banner() {
    echo ""
    echo "${CYAN}${BOLD}  ██╗     ██╗██████╗  █████╗ ██████╗ ██████╗${RESET}"
    echo "${CYAN}${BOLD}  ██║     ██║██╔══██╗██╔══██╗██╔══██╗██╔══██╗${RESET}"
    echo "${CYAN}${BOLD}  ██║     ██║██║  ██║███████║██████╔╝██████╔╝${RESET}"
    echo "${CYAN}${BOLD}  ██║     ██║██║  ██║██╔══██║██╔══██╗██╔══██╗${RESET}"
    echo "${CYAN}${BOLD}  ███████╗██║██████╔╝██║  ██║██║  ██║██║  ██║${RESET}"
    echo "${CYAN}${BOLD}  ╚══════╝╚═╝╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝${RESET}"
    echo ""
    echo "${DIM}  Book & Audiobook Collection Manager${RESET}"
    echo ""
}

section() { echo ""; echo "${BOLD}${WHITE}── $1 $( printf '%.0s─' $(seq 1 $((50 - ${#1}))) )${RESET}"; echo ""; }
ok()      { echo "  ${GREEN}✓${RESET} $1"; }
warn()    { echo "  ${YELLOW}!${RESET} $1"; }
fail()    { echo "  ${RED}✗${RESET} $1"; }
die()     { fail "$1"; echo ""; exit 1; }

prompt() {
    local label="$1" default="$2" var_name="$3"
    local input
    printf "  ${BOLD}%s${RESET} ${DIM}[%s]${RESET}: " "$label" "$default"
    read -r input
    input="${input:-$default}"
    printf -v "$var_name" '%s' "$input"
}

confirm() {
    local label="$1" default="${2:-y}"
    local input
    local hint="[Y/n]"
    [ "$default" = "n" ] && hint="[y/N]"
    printf "  ${BOLD}%s${RESET} ${DIM}%s${RESET}: " "$label" "$hint"
    read -r input
    input="${input:-$default}"
    [[ "$input" =~ ^[Yy] ]]
}

# ─── install dir is wherever this script lives ───────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="$SCRIPT_DIR/docker-compose.yml"
STATE_FILE="$SCRIPT_DIR/.lidarr-install"
IMAGE_ARCHIVE="$SCRIPT_DIR/lidarr-image.tar.gz"

# ─── reconfigure flag ────────────────────────────────────────────────────────
RECONFIGURE=false
for arg in "$@"; do
    [ "$arg" = "--reconfigure" ] && RECONFIGURE=true
done

# ─── welcome ─────────────────────────────────────────────────────────────────
clear
banner

# ─── already installed? ──────────────────────────────────────────────────────
if [ -f "$STATE_FILE" ] && [ "$RECONFIGURE" = false ]; then
    # shellcheck disable=SC1090
    source "$STATE_FILE"
    echo "  ${YELLOW}Lidarr is already installed.${RESET}"
    echo ""
    echo "  ${DIM}Port:    ${RESET}$LIDARR_PORT"
    echo "  ${DIM}Books:   ${RESET}$LIDARR_BOOKS_DIR"
    echo "  ${DIM}Config:  ${RESET}$LIDARR_CONFIG_DIR"
    echo ""
    if ! confirm "Run --reconfigure to change settings. Restart the container instead?"; then
        echo ""
        echo "  Run ${CYAN}./install.sh --reconfigure${RESET} to change settings."
        echo ""
        exit 0
    fi
    docker compose -f "$COMPOSE_FILE" restart
    echo ""
    ok "Lidarr restarted at ${CYAN}http://localhost:${LIDARR_PORT}${RESET}"
    echo ""
    exit 0
fi

# ─── check prerequisites ─────────────────────────────────────────────────────
section "Checking prerequisites"

if command -v docker &>/dev/null; then
    DOCKER_VER=$(docker --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    ok "Docker $DOCKER_VER"
else
    die "Docker not found. Install it from https://docs.docker.com/get-docker/"
fi

if docker compose version &>/dev/null 2>&1; then
    COMPOSE_VER=$(docker compose version --short 2>/dev/null || echo "v2")
    ok "Docker Compose $COMPOSE_VER"
elif command -v docker-compose &>/dev/null; then
    COMPOSE_VER=$(docker-compose --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    ok "docker-compose $COMPOSE_VER (legacy)"
    # alias for the rest of this script
    docker() { if [ "$1" = "compose" ]; then shift; command docker-compose "$@"; else command docker "$@"; fi; }
else
    die "Docker Compose not found. Install it from https://docs.docker.com/compose/install/"
fi

# ─── image source ────────────────────────────────────────────────────────────
section "Docker image"

IMAGE_NAME="lidarr:local"

if docker image inspect "$IMAGE_NAME" &>/dev/null 2>&1; then
    ok "Found image ${CYAN}$IMAGE_NAME${RESET} locally"
elif [ -f "$IMAGE_ARCHIVE" ]; then
    echo "  Loading image from ${CYAN}lidarr-image.tar.gz${RESET}..."
    docker load < "$IMAGE_ARCHIVE"
    ok "Image loaded"
elif confirm "Image not found locally. Pull from registry instead? (requires published image)" "n"; then
    prompt "Registry image" "ghcr.io/yourusername/lidarr:latest" IMAGE_NAME
    docker pull "$IMAGE_NAME"
    ok "Image pulled"
else
    echo ""
    echo "  ${YELLOW}No image available.${RESET} To build it:"
    echo ""
    echo "  ${DIM}  cd $(dirname "$SCRIPT_DIR")${RESET}"
    echo "  ${DIM}  FRONTEND=YES PACKAGES=YES ./build.sh${RESET}"
    echo "  ${DIM}  docker buildx build --platform linux/amd64 \\${RESET}"
    echo "  ${DIM}    --build-arg TARGETPLATFORM=linux/amd64 \\${RESET}"
    echo "  ${DIM}    -t lidarr:local --load .${RESET}"
    echo ""
    echo "  Then re-run this installer."
    echo ""
    exit 1
fi

# ─── setup ───────────────────────────────────────────────────────────────────
section "Setup"

# Port
while true; do
    prompt "Port" "8787" LIDARR_PORT
    if [[ "$LIDARR_PORT" =~ ^[0-9]+$ ]] && [ "$LIDARR_PORT" -ge 1024 ] && [ "$LIDARR_PORT" -le 65535 ]; then
        # check if port is already in use
        if command -v lsof &>/dev/null && lsof -iTCP:"$LIDARR_PORT" -sTCP:LISTEN &>/dev/null 2>&1; then
            warn "Port $LIDARR_PORT is already in use. Choose another."
        else
            break
        fi
    else
        warn "Enter a valid port number (1024–65535)."
    fi
done

echo ""

# Books directory
while true; do
    prompt "Books directory" "$HOME/Books" LIDARR_BOOKS_DIR
    # expand tilde
    LIDARR_BOOKS_DIR="${LIDARR_BOOKS_DIR/#\~/$HOME}"
    if [ -d "$LIDARR_BOOKS_DIR" ]; then
        ok "Directory exists"
        break
    else
        if confirm "  Directory doesn't exist. Create it?"; then
            mkdir -p "$LIDARR_BOOKS_DIR"
            ok "Created $LIDARR_BOOKS_DIR"
            break
        fi
    fi
done

echo ""

# Config directory
while true; do
    prompt "Config directory" "$HOME/.config/lidarr" LIDARR_CONFIG_DIR
    LIDARR_CONFIG_DIR="${LIDARR_CONFIG_DIR/#\~/$HOME}"
    if [ -d "$LIDARR_CONFIG_DIR" ]; then
        ok "Directory exists"
        break
    else
        if confirm "  Directory doesn't exist. Create it?"; then
            mkdir -p "$LIDARR_CONFIG_DIR"
            ok "Created $LIDARR_CONFIG_DIR"
            break
        fi
    fi
done

# ─── pre-seed config.xml with chosen port ────────────────────────────────────
CONFIG_XML="$LIDARR_CONFIG_DIR/config.xml"
if [ ! -f "$CONFIG_XML" ]; then
    cat > "$CONFIG_XML" <<XML
<Config>
  <Port>${LIDARR_PORT}</Port>
  <BindAddress>*</BindAddress>
  <SslPort>9898</SslPort>
  <EnableSsl>False</EnableSsl>
  <LaunchBrowser>False</LaunchBrowser>
  <AuthenticationMethod>None</AuthenticationMethod>
  <AnalyticsEnabled>False</AnalyticsEnabled>
  <Branch>develop</Branch>
  <LogLevel>info</LogLevel>
  <UrlBase></UrlBase>
  <UpdateMechanism>Docker</UpdateMechanism>
</Config>
XML
else
    # Update port in existing config
    if command -v xmlstarlet &>/dev/null; then
        xmlstarlet ed -L -u "/Config/Port" -v "$LIDARR_PORT" "$CONFIG_XML"
    else
        sed -i.bak "s|<Port>[^<]*</Port>|<Port>${LIDARR_PORT}</Port>|" "$CONFIG_XML"
        rm -f "${CONFIG_XML}.bak"
    fi
    ok "Updated port in existing config.xml"
fi

# ─── generate docker-compose.yml ─────────────────────────────────────────────
section "Installing"

echo "  Writing docker-compose.yml..."

cat > "$COMPOSE_FILE" <<YAML
services:
  lidarr:
    image: ${IMAGE_NAME}
    container_name: lidarr
    restart: unless-stopped
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=${TZ:-UTC}
    ports:
      - "${LIDARR_PORT}:8787"
    volumes:
      - ${LIDARR_CONFIG_DIR}:/config
      - ${LIDARR_BOOKS_DIR}:/books
YAML

ok "docker-compose.yml written"

# ─── save install state ───────────────────────────────────────────────────────
cat > "$STATE_FILE" <<STATE
LIDARR_PORT=${LIDARR_PORT}
LIDARR_BOOKS_DIR=${LIDARR_BOOKS_DIR}
LIDARR_CONFIG_DIR=${LIDARR_CONFIG_DIR}
IMAGE_NAME=${IMAGE_NAME}
STATE

# ─── start ───────────────────────────────────────────────────────────────────
echo ""
echo "  Starting Lidarr..."
docker compose -f "$COMPOSE_FILE" up -d

echo ""

# wait for it to be ready (up to 30s)
printf "  Waiting for Lidarr to come up"
for i in $(seq 1 30); do
    if curl -sf "http://localhost:${LIDARR_PORT}/api/v1/system/status" \
        -H "X-Api-Key: placeholder" &>/dev/null 2>&1 || \
       curl -sf "http://localhost:${LIDARR_PORT}" &>/dev/null 2>&1; then
        echo ""
        break
    fi
    printf "."
    sleep 1
done
echo ""

# ─── done ────────────────────────────────────────────────────────────────────
section "Done"

echo "  ${GREEN}${BOLD}Lidarr is running.${RESET}"
echo ""
echo "  ${BOLD}Open:${RESET}    ${CYAN}http://localhost:${LIDARR_PORT}${RESET}"
echo "  ${BOLD}Books:${RESET}   ${LIDARR_BOOKS_DIR}"
echo "  ${BOLD}Config:${RESET}  ${LIDARR_CONFIG_DIR}"
echo ""
echo "  ${DIM}Stop:        docker compose -f \"${COMPOSE_FILE}\" down${RESET}"
echo "  ${DIM}Start:       docker compose -f \"${COMPOSE_FILE}\" up -d${RESET}"
echo "  ${DIM}Logs:        docker compose -f \"${COMPOSE_FILE}\" logs -f${RESET}"
echo "  ${DIM}Reconfigure: $0 --reconfigure${RESET}"
echo ""
