#!/usr/bin/env bash
# Copyright (c) 2025-2026 Greg Ames/Ames & Associates. Licensed under the Coffee Right License — see LICENSE.
# Project: Terminal Switcher | Filename: install.sh
#
# One-line installer (Intel + Apple Silicon):
#   curl -fsSL https://raw.githubusercontent.com/searayca/terminal-switcher/main/install.sh | bash
# Uninstall:
#   curl -fsSL https://raw.githubusercontent.com/searayca/terminal-switcher/main/install.sh | bash -s -- --uninstall
set -euo pipefail

REPO="searayca/terminal-switcher"
RELEASES_PAGE="https://github.com/${REPO}/releases"
APP_NAME="Terminal Switcher.app"
PLIST_LABEL="com.greg.terminal-switcher"

uninstall() {
  echo "Terminal Switcher uninstaller"
  REMOVED=0

  # TS_NO_KILL=1 skips stopping the live process (used for automated tests).
  if [ -z "${TS_NO_KILL:-}" ] && pkill -x TerminalSwitcher 2>/dev/null; then
    echo "Stopped the running Terminal Switcher process."
    REMOVED=1
  fi

  for dir in "/Applications" "${HOME}/Applications"; do
    if [ -e "${dir}/${APP_NAME}" ]; then
      rm -rf "${dir}/${APP_NAME}"
      echo "Removed ${dir}/${APP_NAME}"
      REMOVED=1
    fi
  done

  PLIST="${HOME}/Library/LaunchAgents/${PLIST_LABEL}.plist"
  if [ -e "${PLIST}" ]; then
    launchctl bootout "gui/$(id -u)/${PLIST_LABEL}" 2>/dev/null || true
    rm -f "${PLIST}"
    echo "Removed launch agent ${PLIST}"
    REMOVED=1
  fi

  if [ "${REMOVED}" -eq 0 ]; then
    echo "Nothing to remove — Terminal Switcher was not found on this Mac."
  else
    echo ""
    echo "Terminal Switcher has been uninstalled. Thanks for trying it!"
    echo "Feedback is always welcome: terminal-switcher@ac44.com"
  fi
  exit 0
}

if [ "${1:-}" = "--uninstall" ]; then
  uninstall
fi

echo "Terminal Switcher installer — looking up the latest release..."
ASSET_URL=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" \
  | grep -o '"browser_download_url"[^"]*"[^"]*-universal\.zip"' \
  | sed 's/.*"\(https[^"]*\)"/\1/' | head -n1)

if [ -z "${ASSET_URL}" ]; then
  echo "ERROR: could not find the universal .zip in the latest release." >&2
  echo "Download it manually from: ${RELEASES_PAGE}" >&2
  exit 1
fi

TMPDIR_TS=$(mktemp -d)
trap 'rm -rf "$TMPDIR_TS"' EXIT

echo "Downloading ${ASSET_URL} ..."
if ! curl -fL --progress-bar -o "${TMPDIR_TS}/ts.zip" "${ASSET_URL}"; then
  echo "ERROR: download failed. Grab the zip yourself from: ${RELEASES_PAGE}" >&2
  exit 1
fi
ditto -x -k "${TMPDIR_TS}/ts.zip" "${TMPDIR_TS}/extracted"

# Install dir: INSTALL_DIR override > replace an EXISTING install in place
# (so upgrades never leave a stale duplicate copy behind) > /Applications >
# ~/Applications fallback.
if [ -z "${INSTALL_DIR:-}" ]; then
  if [ -e "/Applications/${APP_NAME}" ]; then
    INSTALL_DIR="/Applications"
  elif [ -e "${HOME}/Applications/${APP_NAME}" ]; then
    INSTALL_DIR="${HOME}/Applications"
  elif [ -w /Applications ]; then
    INSTALL_DIR="/Applications"
  else
    INSTALL_DIR="${HOME}/Applications"
  fi
fi
mkdir -p "${INSTALL_DIR}"
DEST="${INSTALL_DIR}/${APP_NAME}"

UPGRADING=0
if [ -e "${DEST}" ]; then
  UPGRADING=1
  # Only on a real upgrade: stop the running copy before replacing it.
  # TS_NO_KILL=1 skips the kill (used for automated tests).
  if [ -z "${TS_NO_KILL:-}" ]; then
    pkill -x TerminalSwitcher 2>/dev/null || true
  fi
  rm -rf "${DEST}"
fi

cp -R "${TMPDIR_TS}/extracted/${APP_NAME}" "${DEST}"
xattr -dr com.apple.quarantine "${DEST}" 2>/dev/null || true

# TS_NO_LAUNCH=1 skips launching (used for automated install tests).
if [ -z "${TS_NO_LAUNCH:-}" ]; then
  open "${DEST}"
fi

echo ""
echo "Terminal Switcher installed to: ${DEST}"
[ "${UPGRADING}" -eq 1 ] && echo "(Upgraded existing copy and relaunched.)"
echo "First launch: macOS will ask — \"Terminal Switcher\" wants access to control \"Terminal\"."
echo "Click Allow (required). Re-enable later via System Settings > Privacy & Security > Automation."
echo "Questions or problems: terminal-switcher@ac44.com"
echo "Like it? Buy me a coffee → https://buymeacoffee.com/terminalswitcher"
