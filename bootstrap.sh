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
# What it does: clones the repository into a temporary directory
# (install.sh needs its scripts/ and config/ directories alongside),
# executes ./install.sh forwarding all arguments, and removes the
# temporary clone again after a successful run (the installer copies
# files rather than symlinking, so nothing depends on the checkout).
# After a failed run the clone is kept for inspection and re-running.
#
# Overridable via environment:
#   LWS_REPO_URL  repository to clone (default below)
#   LWS_DIR       use a persistent checkout at this path instead of a
#                 temporary clone: it is created or fast-forwarded,
#                 kept afterwards, and never deleted automatically.
# ============================================================

set -Eeuo pipefail

REPO_URL="${LWS_REPO_URL:-https://github.com/Michael-K1/linux-workstation-setup.git}"

info() { printf '[INFO] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
fail() { printf '[FAIL] %s\n' "$*" >&2; exit 1; }

command -v git >/dev/null 2>&1 \
    || fail "git is required to bootstrap. Install it first (e.g. 'sudo apt install git' or 'sudo pacman -S git')."

# ---------- Fetch the repository ----------

EPHEMERAL=false
if [[ -n "${LWS_DIR:-}" ]]; then
    # Persistent mode: keep a reusable checkout at a user-chosen path.
    TARGET_DIR="$LWS_DIR"
    if [[ -d "${TARGET_DIR}/.git" && -f "${TARGET_DIR}/install.sh" ]]; then
        info "Existing checkout found at ${TARGET_DIR}; updating..."
        git -C "$TARGET_DIR" pull --ff-only \
            || warn "Could not fast-forward (local changes?); continuing with the existing version."
    elif [[ -e "$TARGET_DIR" ]]; then
        fail "${TARGET_DIR} exists but is not a linux-workstation-setup checkout. Remove it or choose another LWS_DIR."
    else
        info "Cloning ${REPO_URL} -> ${TARGET_DIR}"
        git clone "$REPO_URL" "$TARGET_DIR" || fail "git clone failed."
    fi
else
    # Default: ephemeral clone in a fresh temporary directory (mktemp
    # avoids predictable /tmp paths on multi-user systems).
    EPHEMERAL=true
    TARGET_DIR=$(mktemp -d "${TMPDIR:-/tmp}/linux-workstation-setup.XXXXXX") \
        || fail "Could not create a temporary directory."
    info "Cloning ${REPO_URL} -> ${TARGET_DIR} (temporary)"
    git clone "$REPO_URL" "$TARGET_DIR" || { rm -rf "$TARGET_DIR"; fail "git clone failed."; }
fi

# ---------- Run the installer ----------

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

# ---------- Cleanup ----------

if [[ "$EPHEMERAL" == true ]]; then
    if [[ "$status" -eq 0 ]]; then
        cd /
        rm -rf "$TARGET_DIR"
        info "Removed the temporary clone. Re-run the curl one-liner anytime to reconfigure."
    else
        warn "Installer finished with errors; keeping ${TARGET_DIR} for inspection."
        warn "It lives under /tmp and disappears on reboot - simply re-run the curl one-liner afterwards."
    fi
else
    info "Keeping ${TARGET_DIR} - re-run ./install.sh from there to reconfigure later."
fi

exit "$status"
