# shellcheck shell=bash
# ============================================================
# install-plugins.sh - Zsh plugin installation.
#
# git                    - built into Oh My Zsh, nothing to install.
# zsh-autosuggestions    - cloned into the OMZ custom plugins directory.
# zsh-syntax-highlighting- cloned into the OMZ custom plugins directory.
#
# Activation (the plugins=() line) is handled by configure-shell.sh,
# which keeps zsh-syntax-highlighting last, as its maintainers require.
# ============================================================

readonly AUTOSUGGESTIONS_REPO="https://github.com/zsh-users/zsh-autosuggestions.git"
readonly SYNTAX_HIGHLIGHTING_REPO="https://github.com/zsh-users/zsh-syntax-highlighting.git"

omz_plugins_dir() {
    printf '%s' "${ZSH_CUSTOM:-$(omz_dir)/custom}/plugins"
}

plugin_installed() {
    [[ -d "$(omz_plugins_dir)/$1" ]]
}

install_plugins() {
    if ! omz_installed; then
        log_error "Plugins are installed into Oh My Zsh; install Oh My Zsh first."
        return 1
    fi

    local failed=0

    log_info "Plugin 'git' is built into Oh My Zsh (enabled via .zshrc)."

    if [[ "${PLUGIN_AUTOSUGGESTIONS:-false}" == true ]]; then
        if plugin_installed zsh-autosuggestions; then
            log_success "zsh-autosuggestions is already installed."
        else
            clone_repo "$AUTOSUGGESTIONS_REPO" "$(omz_plugins_dir)/zsh-autosuggestions" || failed=1
        fi
    fi

    if [[ "${PLUGIN_SYNTAX_HIGHLIGHTING:-false}" == true ]]; then
        if plugin_installed zsh-syntax-highlighting; then
            log_success "zsh-syntax-highlighting is already installed."
        else
            clone_repo "$SYNTAX_HIGHLIGHTING_REPO" "$(omz_plugins_dir)/zsh-syntax-highlighting" || failed=1
        fi
    fi

    return "$failed"
}
