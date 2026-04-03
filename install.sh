#!/usr/bin/env bash
# whiptail-replay installer
# Usage: bash -c "$(curl -fsSL https://raw.githubusercontent.com/StevenVanAcker/whiptail-replay/main/install.sh)"

set -euo pipefail

GITHUB_RAW="https://raw.githubusercontent.com/StevenVanAcker/whiptail-replay/main"
INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"
WRAPPER="$INSTALL_DIR/whiptail"

# ---------------------------------------------------------------------------
# Colours
# ---------------------------------------------------------------------------
YW=$(echo "\033[33m")
GN=$(echo "\033[1;92m")
RD=$(echo "\033[01;31m")
BL=$(echo "\033[36m")
CM=$(echo "\033[0;92m \xE2\x9C\x94\033[0m")
CROSS=$(echo "\033[0;91m \xE2\x9C\x98\033[0m")
CL=$(echo "\033[m")

msg_info()  { local msg="$1"; echo -ne " ${YW}${msg}...${CL}"; }
msg_ok()    { local msg="$1"; echo -e "${CM} ${GN}${msg}${CL}"; }
msg_error() { local msg="$1"; echo -e "${CROSS} ${RD}${msg}${CL}"; }

header() {
  echo -e "\n${BL}╔══════════════════════════════════════════╗${CL}"
  echo -e "${BL}║${CL}  ${GN}whiptail-replay${CL} installer               ${BL}║${CL}"
  echo -e "${BL}╚══════════════════════════════════════════╝${CL}\n"
}

# ---------------------------------------------------------------------------
# Preflight checks
# ---------------------------------------------------------------------------
if [[ "$EUID" -ne 0 ]]; then
  msg_error "This script must be run as root (try: sudo bash -c \"\$(curl ...)\")"
  exit 1
fi

if ! command -v python3 &>/dev/null; then
  msg_error "python3 is required but was not found"
  exit 1
fi

if ! command -v curl &>/dev/null; then
  msg_error "curl is required but was not found"
  exit 1
fi

if [[ ! -d "$INSTALL_DIR" ]]; then
  msg_error "Install directory '$INSTALL_DIR' does not exist"
  exit 1
fi

# ---------------------------------------------------------------------------
# Detect the real whiptail before we shadow it
# ---------------------------------------------------------------------------
REAL_WHIPTAIL="$(command -v whiptail 2>/dev/null || true)"
if [[ -z "$REAL_WHIPTAIL" || "$REAL_WHIPTAIL" == "$WRAPPER" ]]; then
  REAL_WHIPTAIL="/usr/bin/whiptail"
fi

# ---------------------------------------------------------------------------
# Install
# ---------------------------------------------------------------------------
header

msg_info "Downloading whiptail-replay"
curl -fsSL "$GITHUB_RAW/whiptail-replay" -o "$WRAPPER"
chmod 755 "$WRAPPER"
msg_ok "Downloaded and installed to $WRAPPER"

msg_info "Verifying installation"
if python3 "$WRAPPER" --list &>/dev/null || true; then
  msg_ok "whiptail-replay is working"
else
  msg_error "Verification failed — check $WRAPPER"
  exit 1
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo -e "\n${GN}Installation complete!${CL}\n"
echo -e "  Installed at : ${BL}${WRAPPER}${CL}"
echo -e "  Shadows      : ${BL}${REAL_WHIPTAIL}${CL}"
echo -e "\n${YW}Quick start:${CL}"
echo -e ""
echo -e "  ${GN}Record answers interactively:${CL}"
echo -e "    export WHIPTAILREPLAYFILE=/path/to/answers.json"
echo -e "    export WHIPTAILRECORD=1"
echo -e "    export WHIPTAILPATH=${REAL_WHIPTAIL}"
echo -e "    your-script.sh"
echo -e ""
echo -e "  ${GN}Replay non-interactively:${CL}"
echo -e "    export WHIPTAILREPLAYFILE=/path/to/answers.json"
echo -e "    your-script.sh"
echo -e ""
echo -e "  ${GN}List recorded answers:${CL}"
echo -e "    WHIPTAILREPLAYFILE=/path/to/answers.json whiptail --list"
echo -e ""
echo -e "  See ${BL}https://github.com/StevenVanAcker/whiptail-replay${CL} for full documentation.\n"
