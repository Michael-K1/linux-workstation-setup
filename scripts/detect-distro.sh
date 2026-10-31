# shellcheck shell=bash
# ============================================================
# detect-distro.sh - distribution detection via /etc/os-release.
#
# Sets:
#   DISTRO_ID        - os-release ID (e.g. ubuntu, arch, bazzite)
#   DISTRO_NAME      - human-readable name
#   DISTRO_LIKE      - os-release ID_LIKE
#   PKG_MANAGER      - apt | pacman | rpm-ostree | "" (none)
#   IMMUTABLE        - true when the host is OSTree-based (e.g. Bazzite)
#   DISTRO_SUPPORTED - true only for explicitly supported distributions
# ============================================================

detect_distro() {
    DISTRO_ID="unknown"
    DISTRO_NAME="Unknown"
    DISTRO_LIKE=""
    PKG_MANAGER=""
    IMMUTABLE=false
    DISTRO_SUPPORTED=false

    if [[ ! -r /etc/os-release ]]; then
        log_warn "/etc/os-release not found; distribution cannot be detected."
        return 0
    fi

    # Read os-release in a subshell so it cannot pollute our environment.
    DISTRO_ID=$(. /etc/os-release && printf '%s' "${ID:-unknown}")
    DISTRO_NAME=$(. /etc/os-release && printf '%s' "${PRETTY_NAME:-${NAME:-Unknown}}")
    DISTRO_LIKE=$(. /etc/os-release && printf '%s' "${ID_LIKE:-}")

    # OSTree-based systems (Bazzite, Silverblue, ...) are immutable hosts.
    if [[ -f /run/ostree-booted ]]; then
        IMMUTABLE=true
    fi

    case "$DISTRO_ID" in
        ubuntu|debian)
            PKG_MANAGER="apt"
            DISTRO_SUPPORTED=true
            ;;
        arch|cachyos)
            PKG_MANAGER="pacman"
            DISTRO_SUPPORTED=true
            ;;
        bazzite)
            PKG_MANAGER="rpm-ostree"
            IMMUTABLE=true
            DISTRO_SUPPORTED=true
            ;;
        *)
            # Not explicitly supported: fall back on ID_LIKE, but only to
            # package managers this project explicitly knows how to drive.
            if [[ " ${DISTRO_LIKE} " == *debian* || " ${DISTRO_LIKE} " == *ubuntu* ]]; then
                PKG_MANAGER="apt"
            elif [[ " ${DISTRO_LIKE} " == *arch* ]]; then
                PKG_MANAGER="pacman"
            elif [[ "$IMMUTABLE" == true ]] && command_exists rpm-ostree; then
                PKG_MANAGER="rpm-ostree"
            fi
            ;;
    esac
}

print_system_info() {
    log_info "Distribution:    ${DISTRO_NAME} (id: ${DISTRO_ID})"
    if [[ -n "$DISTRO_LIKE" ]]; then
        log_info "Based on:        ${DISTRO_LIKE}"
    fi
    log_info "Package manager: ${PKG_MANAGER:-none detected}"
    log_info "Immutable host:  ${IMMUTABLE}"
    log_info "User / home:     ${USER:-$(id -un)} / ${HOME}"
}

# confirm_distro_support
# Warns on unsupported distributions and lets the user abort. Continuing is
# only offered when a supported package manager was detected via ID_LIKE.
confirm_distro_support() {
    if [[ "$DISTRO_SUPPORTED" == true ]]; then
        return 0
    fi
    log_warn "'${DISTRO_NAME}' is not an officially supported distribution."
    log_warn "Supported: Ubuntu, Debian, Arch Linux, CachyOS, Bazzite."
    if [[ -z "$PKG_MANAGER" ]]; then
        log_error "No supported package manager was detected. Aborting."
        return 1
    fi
    log_warn "A supported package manager was detected (${PKG_MANAGER}), so you may continue at your own risk."
    if ! ask_yes_no "Continue anyway?" n; then
        log_info "Aborted at user request."
        return 1
    fi
}
