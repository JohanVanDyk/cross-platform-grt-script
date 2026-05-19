#!/usr/bin/env bash
# Build & run Gordon's Reloading Tool in a Linux Mint container with a browser-based noVNC desktop.
# Avoids host X11/XQuartz by running Xvfb + openbox + x11vnc + noVNC inside the container.
set -euo pipefail

OS_KIND="$(uname -s)"     # Linux | Darwin
ARCH_KIND="$(uname -m)"   # x86_64 | arm64 | aarch64

# ---------- config ----------
TARBALL_DEFAULT="GordonsReloadingTool-2021.2040-NIGHTLY-linux.tar.gz"
TARBALL="${GRT_TARBALL:-$TARBALL_DEFAULT}"
IMAGE_NAME="${GRT_IMAGE:-grt-mint-novnc:2021.2040}"
CONTAINER_NAME="${GRT_CONTAINER:-grt}"
BUILD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="${GRT_DATA_DIR:-$BUILD_DIR/data}"   # persists user prefs / loads
NOVNC_BIND="${GRT_NOVNC_BIND:-127.0.0.1}"     # keep browser desktop local by default
NOVNC_PORT="${GRT_NOVNC_PORT:-6080}"
VNC_RESOLUTION="${GRT_VNC_RESOLUTION:-1920x900x24}"

# ---------- preflight ----------
command -v docker >/dev/null || { echo "docker not installed"; exit 1; }
[[ -f "$TARBALL" ]] || { echo "tarball not found: $TARBALL"; exit 1; }

mkdir -p "$BUILD_DIR/context" "$DATA_DIR"
cp -f "$TARBALL" "$BUILD_DIR/context/grt.tar.gz"

# ---------- Dockerfile ----------
cat > "$BUILD_DIR/context/Dockerfile" <<'DOCKERFILE'
# Linux Mint 21.3 (Virginia) — Ubuntu 22.04 jammy base
FROM linuxmintd/mint21.3-amd64

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8

# Enable i386 multiarch — GRT is a 32-bit binary.
# Xvfb/openbox/x11vnc/noVNC provide an internal browser-accessible desktop, so no host X11/XQuartz is required.
RUN dpkg --add-architecture i386 && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates locales \
        xvfb x11vnc openbox novnc websockify \
        xdg-utils desktop-file-utils shared-mime-info feh \
        libc6:i386 libstdc++6:i386 libgcc-s1:i386 \
        libgtk2.0-0:i386 libgdk-pixbuf-2.0-0:i386 libatk1.0-0:i386 \
        libpango-1.0-0:i386 libpangocairo-1.0-0:i386 libcairo2:i386 \
        libfontconfig1:i386 libfreetype6:i386 \
        libx11-6:i386 libxext6:i386 libxrender1:i386 libxi6:i386 \
        libxrandr2:i386 libxcursor1:i386 libxfixes3:i386 libxinerama1:i386 \
        libglib2.0-0:i386 libssl3:i386 \
        libcanberra-gtk-module:i386 \
        gtk2-engines-pixbuf:i386 gtk2-engines-murrine:i386 \
        adwaita-icon-theme hicolor-icon-theme \
        fonts-dejavu-core fonts-liberation && \
    sed -i 's/^# *\(en_US.UTF-8\)/\1/' /etc/locale.gen && locale-gen && \
    rm -rf /var/lib/apt/lists/*

COPY grt.tar.gz /tmp/grt.tar.gz
RUN mkdir -p /opt/grt && \
    tar -xzf /tmp/grt.tar.gz --strip-components=1 -C /opt/grt && \
    rm /tmp/grt.tar.gz && \
    chmod +x /opt/grt/GordonsReloadingTool

# Let GRT open generated image files from inside the noVNC desktop.
# Without a registered image handler, xdg-open falls back through missing browsers/viewers.
RUN mkdir -p /etc/xdg && \
    printf '%s\n' \
      '[Default Applications]' \
      'image/jpeg=feh.desktop' \
      'image/jpg=feh.desktop' \
      'image/png=feh.desktop' \
      'image/gif=feh.desktop' \
      'image/bmp=feh.desktop' \
      'image/tiff=feh.desktop' \
      'image/webp=feh.desktop' \
      > /etc/xdg/mimeapps.list && \
    update-mime-database /usr/share/mime >/dev/null 2>&1 || true && \
    update-desktop-database /usr/share/applications >/dev/null 2>&1 || true

RUN cat > /usr/local/bin/start-grt-novnc <<'STARTER' && chmod +x /usr/local/bin/start-grt-novnc
#!/usr/bin/env bash
set -euo pipefail

export DISPLAY="${DISPLAY:-:99}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/runtime-grt}"
export GTK_MODULES="${GTK_MODULES:-}"
export NO_AT_BRIDGE="${NO_AT_BRIDGE:-1}"
export XDG_CURRENT_DESKTOP="${XDG_CURRENT_DESKTOP:-LXDE}"

VNC_RESOLUTION="${VNC_RESOLUTION:-1920x900x24}"
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"
rm -f /tmp/.X99-lock

cleanup() {
    for pid in ${GRT_PID:-} ${NOVNC_PID:-} ${X11VNC_PID:-} ${OPENBOX_PID:-} ${XVFB_PID:-}; do
        [[ -n "$pid" ]] && kill "$pid" >/dev/null 2>&1 || true
    done
}
trap cleanup EXIT INT TERM

Xvfb "$DISPLAY" -screen 0 "$VNC_RESOLUTION" -nolisten tcp >/tmp/xvfb.log 2>&1 &
XVFB_PID=$!
sleep 1

openbox >/tmp/openbox.log 2>&1 &
OPENBOX_PID=$!

x11vnc -display "$DISPLAY" -forever -shared -nopw -listen 127.0.0.1 -rfbport 5900 -xkb >/tmp/x11vnc.log 2>&1 &
X11VNC_PID=$!

websockify --web=/usr/share/novnc/ 0.0.0.0:6080 127.0.0.1:5900 >/tmp/novnc.log 2>&1 &
NOVNC_PID=$!

cd /opt/grt
./GordonsReloadingTool "$@" &
GRT_PID=$!
wait "$GRT_PID"
STARTER

WORKDIR /opt/grt
ENTRYPOINT ["/usr/local/bin/start-grt-novnc"]
DOCKERFILE

# ---------- build ----------
BUILD_ARGS=()
RUN_PLATFORM_ARGS=()

# Force amd64 on Apple Silicon — image only published for amd64; uses Rosetta/qemu.
if [[ "$OS_KIND" == "Darwin" && ( "$ARCH_KIND" == "arm64" || "$ARCH_KIND" == "aarch64" ) ]]; then
    BUILD_ARGS+=( --platform linux/amd64 )
    RUN_PLATFORM_ARGS+=( --platform linux/amd64 )
    echo "[!] Apple Silicon detected — building/running linux/amd64 under emulation."
    echo "    GRT is 32-bit i386 on top of that; expect slow startup, may misbehave."
fi

echo "[+] building image $IMAGE_NAME"
docker build "${BUILD_ARGS[@]}" -t "$IMAGE_NAME" "$BUILD_DIR/context"

# ---------- run ----------
RUN_ARGS=( --rm -it --init --name "$CONTAINER_NAME" \
           -e "XDG_RUNTIME_DIR=/tmp/runtime-grt" \
           -e "GDK_SCALE=${GDK_SCALE:-1}" \
           -e "VNC_RESOLUTION=$VNC_RESOLUTION" \
           -v "$DATA_DIR:/root" \
           -p "$NOVNC_BIND:$NOVNC_PORT:6080" )

RUN_ARGS+=( "${RUN_PLATFORM_ARGS[@]}" )

docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true

URL="http://localhost:${NOVNC_PORT}/vnc.html?host=localhost&port=${NOVNC_PORT}&autoconnect=1&resize=scale"
echo "[+] launching $CONTAINER_NAME with browser desktop"
echo "[+] open: $URL"
exec docker run "${RUN_ARGS[@]}" "$IMAGE_NAME" "$@"
