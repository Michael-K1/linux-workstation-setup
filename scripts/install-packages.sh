# shellcheck shell=bash
# ============================================================
# install-packages.sh - package manager abstraction.
#
# Keeps distro-specific commands in one place so the rest of the
# project can simply call pkg_install.
# ============================================================

PKG_CACHE_UPDATED=false
# Consumed by install.sh (show_results).
# shellcheck disable=SC2034
REBOOT_REQUIRED=false

# pkg_install <package>...
# Installs native packages with the detected package manager.
pkg_install() {
    case "$PKG_MANAGER" in
        apt)
            if [[ "$PKG_CACHE_UPDATED" == false ]]; then
                log_info "Updating APT package index..."
                as_root apt-get update -qq || return 1
                PKG_CACHE_UPDATED=true
            fi
            as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y "$@"
            ;;
        pacman)
            # --needed makes this idempotent (already-installed packages are
            # skipped). We intentionally do not run a full -Syu here; keeping
            # the system updated is the user's responsibility (partial
            # upgrades are unsafe on Arch-based systems).
            as_root pacman -S --needed --noconfirm "$@"
            ;;
        rpm-ostree)
            # Layering onto an immutable host: changes only take effect after
            # a reboot. --idempotent makes re-runs safe.
            log_warn "Layering package(s) onto the immutable host: $*"
            if as_root rpm-ostree install --idempotent "$@"; then
                # Consumed by install.sh (show_results).
                # shellcheck disable=SC2034
                REBOOT_REQUIRED=true
            else
                return 1
            fi
            ;;
        *)
            log_error "No supported package manager available; cannot install: $*"
            return 1
            ;;
    esac
}

# ensure_base_tools
# git and curl/wget are needed for Oh My Zsh, plugins and fonts. On Bazzite
# both ship with the base image; we never layer them automatically.
ensure_base_tools() {
    local missing=()
    command_exists git || missing+=(git)
    command_exists curl || command_exists wget || missing+=(curl)
    if [[ ${#missing[@]} -eq 0 ]]; then
        return 0
    fi
    log_warn "Missing required tools: ${missing[*]}"
    if [[ "$PKG_MANAGER" == "rpm-ostree" ]]; then
        log_error "git/curl are expected in the Bazzite base image. Install them manually (e.g. inside a Distrobox) and re-run."
        return 1
    fi
    if ask_yes_no "Install missing tools (${missing[*]}) now?" y; then
        pkg_install "${missing[@]}"
    else
        log_error "Cannot continue without: ${missing[*]}"
        return 1
    fi
}
