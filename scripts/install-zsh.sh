# shellcheck shell=bash
# ============================================================
# install-zsh.sh - install Zsh with the native package manager.
# ============================================================

zsh_installed() {
    command_exists zsh
}

install_zsh() {
    if zsh_installed; then
        log_success "Zsh is already installed: $(zsh --version)"
        ensure_zsh_in_etc_shells
        return 0
    fi

    if [[ "$PKG_MANAGER" == "rpm-ostree" ]]; then
        log_warn "Bazzite is an immutable distribution. Installing Zsh on the host requires"
        log_warn "layering it with rpm-ostree, which only takes effect after a reboot."
        if ! ask_yes_no "Layer zsh onto the host with rpm-ostree?" y; then
            log_info "Skipping Zsh installation."
            return 1
        fi
    fi

    pkg_install zsh || { log_error "Zsh installation failed."; return 1; }

    if ! zsh_installed; then
        if [[ "$PKG_MANAGER" == "rpm-ostree" ]]; then
            log_warn "Zsh was layered but is not available until you reboot."
            log_warn "After rebooting, re-run ./install.sh to finish the remaining steps (safe to repeat)."
        else
            log_error "Zsh was installed but the 'zsh' command is still not available."
        fi
        return 1
    fi

    log_success "Zsh installed: $(zsh --version)"
    ensure_zsh_in_etc_shells
}

# ensure_zsh_in_etc_shells
# chsh refuses shells not listed in /etc/shells; offer to register it.
ensure_zsh_in_etc_shells() {
    local zsh_path
    zsh_path=$(command -v zsh) || return 0
    if grep -qx "$zsh_path" /etc/shells 2>/dev/null; then
        return 0
    fi
    log_warn "${zsh_path} is not listed in /etc/shells."
    if [[ "${NON_INTERACTIVE:-false}" == true ]]; then
        # Modifying /etc/shells needs sudo, which may prompt for a password
        # and hang automation; leave it to the user instead.
        log_warn "Non-interactive mode: not modifying /etc/shells. Add it manually if chsh refuses zsh."
        return 0
    fi
    if ask_yes_no "Add ${zsh_path} to /etc/shells (requires root)?" y; then
        if printf '%s\n' "$zsh_path" | as_root tee -a /etc/shells >/dev/null; then
            log_success "Added ${zsh_path} to /etc/shells."
        else
            log_warn "Could not update /etc/shells; changing the default shell may fail."
        fi
    fi
}
