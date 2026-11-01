# shellcheck shell=bash
# ============================================================
# install-prompt.sh - prompt engine installation.
#
# Starship    - installed natively via pacman on Arch/CachyOS; everywhere
#               else (incl. Bazzite) the official installer places a
#               user-level binary in ~/.local/bin (no root, no layering).
# Powerlevel10k - cloned into the Oh My Zsh custom themes directory.
#
# Only the selected engine is installed and activated; activation itself
# happens in configure-shell.sh (theme line in .zshrc + prompt.zsh module).
# ============================================================

readonly STARSHIP_INSTALL_URL="https://starship.rs/install.sh"
readonly P10K_REPO_URL="https://github.com/romkatv/powerlevel10k.git"

starship_installed() {
    command_exists starship || [[ -x "$HOME/.local/bin/starship" ]]
}

p10k_dir() {
    printf '%s' "${ZSH_CUSTOM:-$(omz_dir)/custom}/themes/powerlevel10k"
}

p10k_installed() {
    [[ -f "$(p10k_dir)/powerlevel10k.zsh-theme" ]]
}

install_starship() {
    if starship_installed; then
        log_success "Starship is already installed."
        apply_starship_preset
        return 0
    fi

    if [[ "$PKG_MANAGER" == "pacman" ]]; then
        pkg_install starship || return 1
    else
        # Not packaged in Debian/Ubuntu repos; user-level install also avoids
        # rpm-ostree layering on Bazzite.
        local tmp
        tmp=$(mktemp)
        # shellcheck disable=SC2064
        trap "rm -f '$tmp'" RETURN
        log_info "Downloading the official Starship installer..."
        download_script "$STARSHIP_INSTALL_URL" "$tmp" || return 1
        mkdir -p "$HOME/.local/bin"
        log_info "Installing Starship to ~/.local/bin ..."
        if ! sh "$tmp" -y -b "$HOME/.local/bin" >/dev/null; then
            log_error "Starship installation failed."
            return 1
        fi
    fi

    starship_installed || { log_error "Starship installation finished but the binary was not found."; return 1; }
    log_success "Starship installed."
    apply_starship_preset
}

# apply_starship_preset - apply the preset from $STARSHIP_PRESET via the
# `starship preset` command. Only runs when no ~/.config/starship.toml
# exists yet: an existing configuration is always preserved.
apply_starship_preset() {
    local preset="${STARSHIP_PRESET:-none}"
    local config="$HOME/.config/starship.toml"
    local starship_bin

    if [[ "$preset" == "none" || -z "$preset" ]]; then
        log_info "No Starship preset configured; using Starship's built-in defaults."
        return 0
    fi
    if [[ -f "$config" ]]; then
        log_info "Existing ~/.config/starship.toml found; leaving it untouched."
        return 0
    fi

    if command_exists starship; then
        starship_bin="starship"
    elif [[ -x "$HOME/.local/bin/starship" ]]; then
        starship_bin="$HOME/.local/bin/starship"
    else
        log_warn "Starship binary not found; cannot apply the '${preset}' preset."
        return 0
    fi

    mkdir -p "${config%/*}"
    if "$starship_bin" preset "$preset" -o "$config" 2>/dev/null && [[ -s "$config" ]]; then
        log_success "Applied Starship preset '${preset}' -> ~/.config/starship.toml"
    else
        rm -f "$config"  # don't leave a broken/empty config behind
        log_warn "Could not apply Starship preset '${preset}' (run 'starship preset --list' for valid names)."
        log_warn "Continuing with Starship's built-in defaults."
    fi
}

install_p10k() {
    if p10k_installed; then
        log_success "Powerlevel10k is already installed."
        return 0
    fi
    if ! omz_installed; then
        log_error "Powerlevel10k is installed as an Oh My Zsh theme; install Oh My Zsh first."
        return 1
    fi
    clone_repo "$P10K_REPO_URL" "$(p10k_dir)" || return 1
    log_info "Powerlevel10k's interactive wizard will start on the first Zsh launch (config: ~/.p10k.zsh)."
}

# install_prompt_engine - dispatch based on $PROMPT_ENGINE.
install_prompt_engine() {
    case "${PROMPT_ENGINE:-none}" in
        starship) install_starship ;;
        p10k)     install_p10k ;;
        none)
            log_info "Keeping the current prompt configuration."
            return 0
            ;;
        *)
            log_error "Unknown prompt engine: ${PROMPT_ENGINE} (expected: starship | p10k | none)"
            return 1
            ;;
    esac
}
