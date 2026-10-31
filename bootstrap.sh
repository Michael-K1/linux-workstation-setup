#!/usr/bin/env bash
# ============================================================
# bootstrap.sh - one-line remote bootstrap for linux-workstation-setup.
#
# Recommended usage (keeps stdin on the terminal, so menus work):
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/Michael-K1/linux-workstation-setup/main/bootstrap.sh)"
#
# With installer arguments (note the '--' placeholder for $0):
#   bash -c "$(curl -fsSL .../bootstrap.sh)" -- -y
#   bash -c "$(curl -fsSL .../bootstrap.sh)" -- -n --prompt p10k
#
# Piping (curl ... | bash) also works: stdin is then re-attached to
# /dev/tty so the interactive menus keep working.
#
# What it does: clones the repository (install.sh needs its scripts/
# and config/ directories alongside), executes ./install.sh forwarding
# all arguments, and finally offers to remove the checkout again (the
# installer copies files rather than symlinking, so nothing depends on
# the checkout afterwards).
#
# Overridable via environment:
#   LWS_REPO_URL  repository to clone (default below)
#   LWS_DIR       checkout location (default: ~/linux-workstation-setup)
#   LWS_CLEANUP   true  = remove a freshly made checkout after success
#                 false = always keep it (never ask)
#                 unset = ask in interactive runs, keep in unattended ones
# ============================================================

set -Eeuo pipefail

REPO_URL="${LWS_REPO_URL:-https://github.com/Michael-K1/linux-workstation-setup.git}"
TARGET_DIR="${LWS_DIR:-$HOME/linux-workstation-setup}"

info() { printf '[INFO] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
fail() { printf '[FAIL] %s\n' "$*" >&2; exit 1; }

command -v git >/dev/null 2>&1 \
    || fail "git is required to bootstrap. Install it first (e.g. 'sudo apt install git' or 'sudo pacman -S git')."

# ---------- Fetch the repository ----------

FRESH_CLONE=false
if [[ -d "${TARGET_DIR}/.git" && -f "${TARGET_DIR}/install.sh" ]]; then
    info "Existing checkout found at ${TARGET_DIR}; updating..."
    git -C "$TARGET_DIR" pull --ff-only \
        || warn "Could not fast-forward (local changes?); continuing with the existing version."
elif [[ -e "$TARGET_DIR" ]]; then
    fail "${TARGET_DIR} exists but is not a linux-workstation-setup checkout. Remove it or set LWS_DIR to another path."
else
    info "Cloning ${REPO_URL} -> ${TARGET_DIR}"
    git clone "$REPO_URL" "$TARGET_DIR" || fail "git clone failed."
    FRESH_CLONE=true
fi

# ---------- Run the installer ----------

# Detect unattended runs so we never ask our own question afterwards.
UNATTENDED=false
for arg in "$@"; do
    case "$arg" in
        -n|--non-interactive|-y|--yes) UNATTENDED=true ;;
    esac
done

cd "$TARGET_DIR"
chmod +x install.sh

status=0
if [[ ! -t 0 && -r /dev/tty ]]; then
    # When piped into bash, stdin is the pipe - re-attach the terminal
    # so the interactive menus work.
    ./install.sh "$@" < /dev/tty || status=$?
else
    ./install.sh "$@" || status=$?
fi

# ---------- Optional cleanup of the checkout ----------

# Only a checkout we created in THIS run is ever removed (a pre-existing
# one may be the user's working copy), and only after a fully successful
# installation (on Bazzite, a pending reboot needs a re-run from it).
offer_cleanup() {
    [[ "$FRESH_CLONE" == true && "$status" -eq 0 ]] || return 1
    case "${LWS_CLEANUP:-}" in
        true)  return 0 ;;
        false) return 1 ;;
    esac
    [[ "$UNATTENDED" == true ]] && return 1
    local answer=""
    info "The installed environment does not depend on the checkout (files are copied, not symlinked)."
    if [[ -t 0 ]]; then
        read -r -p "Remove the cloned repository at ${TARGET_DIR}? [y/N] " answer || answer=""
    elif [[ -r /dev/tty ]]; then
        read -r -p "Remove the cloned repository at ${TARGET_DIR}? [y/N] " answer < /dev/tty || answer=""
    else
        return 1
    fi
    [[ "${answer,,}" == y || "${answer,,}" == yes ]]
}

if offer_cleanup; then
    cd "$HOME"
    rm -rf "$TARGET_DIR"
    info "Removed ${TARGET_DIR}. Re-run the curl one-liner anytime to reconfigure."
elif [[ "$FRESH_CLONE" == true && "$status" -eq 0 ]]; then
    info "Keeping ${TARGET_DIR} - re-run ./install.sh from there to reconfigure later."
elif [[ "$status" -ne 0 ]]; then
    warn "Installer finished with errors; keeping ${TARGET_DIR} so you can re-run it."
fi

exit "$status"
