#!/usr/bin/env bash
set -euo pipefail

# ─── colors ──────────────────────────────────────────────────────────────────
if [ -t 1 ] && command -v tput &>/dev/null && tput colors &>/dev/null; then
    BOLD=$(tput bold); RESET=$(tput sgr0)
    RED=$(tput setaf 1); GREEN=$(tput setaf 2); YELLOW=$(tput setaf 3)
    CYAN=$(tput setaf 6); DIM=$(tput dim)
else
    BOLD=''; RESET=''; RED=''; GREEN=''; YELLOW=''; CYAN=''; DIM=''
fi

ok()   { echo "  ${GREEN}✓${RESET} $1"; }
warn() { echo "  ${YELLOW}!${RESET} $1"; }
fail() { echo "  ${RED}✗${RESET} $1"; }
die()  { fail "$1"; echo ""; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

IMAGE_NAME="lidarr:local"
IMAGE_ARCHIVE="$SCRIPT_DIR/lidarr-image.tar.gz"

# ─── version ─────────────────────────────────────────────────────────────────
VERSION="${1:-}"
if [ -z "$VERSION" ]; then
    if git -C "$REPO_ROOT" rev-parse --short HEAD &>/dev/null 2>&1; then
        VERSION="$(git -C "$REPO_ROOT" rev-parse --short HEAD)"
    else
        VERSION="local"
    fi
fi

OUT_ARCHIVE="$SCRIPT_DIR/lidarr-install-${VERSION}.tar.gz"

echo ""
echo "${BOLD}${CYAN}Lidarr — package builder${RESET}"
echo ""

# ─── check image ─────────────────────────────────────────────────────────────
if ! docker image inspect "$IMAGE_NAME" &>/dev/null 2>&1; then
    echo "  ${RED}Image ${CYAN}$IMAGE_NAME${RED} not found.${RESET}"
    echo ""
    echo "  Build it first:"
    echo ""
    echo "  ${DIM}  mise install${RESET}"
    echo "  ${DIM}  FRONTEND=YES PACKAGES=YES ./build.sh${RESET}"
    echo "  ${DIM}  docker buildx build --platform linux/amd64 \\${RESET}"
    echo "  ${DIM}    --build-arg TARGETPLATFORM=linux/amd64 \\${RESET}"
    echo "  ${DIM}    --build-arg GIT_BRANCH=develop \\${RESET}"
    echo "  ${DIM}    --build-arg COMMIT_HASH=\$(git rev-parse --short HEAD) \\${RESET}"
    echo "  ${DIM}    --build-arg BUILD_DATE=\$(date -u +%Y-%m-%dT%H:%M:%SZ) \\${RESET}"
    echo "  ${DIM}    -t lidarr:local --load .${RESET}"
    echo ""
    exit 1
fi

ok "Found image ${CYAN}$IMAGE_NAME${RESET}"

# ─── export image ─────────────────────────────────────────────────────────────
echo ""
echo "  Exporting image (this may take a minute)..."
docker save "$IMAGE_NAME" | gzip > "$IMAGE_ARCHIVE"
IMAGE_SIZE=$(du -sh "$IMAGE_ARCHIVE" | cut -f1)
ok "Image saved to ${CYAN}lidarr-image.tar.gz${RESET} (${IMAGE_SIZE})"

# ─── bundle ──────────────────────────────────────────────────────────────────
echo ""
echo "  Bundling install package..."

tar -czf "$OUT_ARCHIVE" \
    -C "$SCRIPT_DIR" \
    install.sh \
    lidarr-image.tar.gz

BUNDLE_SIZE=$(du -sh "$OUT_ARCHIVE" | cut -f1)
ok "Package ready: ${CYAN}lidarr-install-${VERSION}.tar.gz${RESET} (${BUNDLE_SIZE})"

# ─── clean up intermediate archive ───────────────────────────────────────────
rm -f "$IMAGE_ARCHIVE"

# ─── done ────────────────────────────────────────────────────────────────────
echo ""
echo "  ${BOLD}Transfer to target machine:${RESET}"
echo ""
echo "  ${DIM}scp install/lidarr-install-${VERSION}.tar.gz user@host:~/${RESET}"
echo ""
echo "  ${BOLD}On the target machine:${RESET}"
echo ""
echo "  ${DIM}tar -xzf lidarr-install-${VERSION}.tar.gz${RESET}"
echo "  ${DIM}chmod +x install.sh && ./install.sh${RESET}"
echo ""
