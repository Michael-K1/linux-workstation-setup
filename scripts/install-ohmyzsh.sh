# shellcheck shell=bash
# ============================================================
# install-ohmyzsh.sh - install Oh My Zsh via the official script.
#
# The script is downloaded to a temporary file and sanity-checked
# before execution (never piped straight from curl). It is run with:
#   RUNZSH=no     - do not launch a new shell afterwards
#   CHSH=no       - do not change the default shell (we handle that)
#   KEEP_ZSHRC=yes- never touch an existing ~/.zshrc
# ============================================================

readonly OMZ_INSTALL_URL="https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh"

# Set to true when the OMZ installer created ~/.zshrc during this run (fresh
# systems have none, and the installer then writes its stock template even
# with KEEP_ZSHRC=yes). deploy_zsh_config may safely replace that file.
OMZ_CREATED_ZSHRC=false

omz_dir() {
    printf '%s' "${ZSH:-$HOME/.oh-my-zsh}"
}

omz_installed() {
    [[ -f "$(omz_dir)/oh-my-zsh.sh" ]]
}

install_oh_my_zsh() {
    if omz_installed; then
        log_success "Oh My Zsh is already installed at $(omz_dir)."
        return 0
    fi

    if ! zsh_installed; then
        log_error "Oh My Zsh requires Zsh. Install Zsh first (on Bazzite: reboot after layering, then re-run)."
        return 1
    fi

    local tmp
    tmp=$(mktemp)
    # shellcheck disable=SC2064
    trap "rm -f '$tmp'" RETURN

    log_info "Downloading the official Oh My Zsh install script..."
    download_script "$OMZ_INSTALL_URL" "$tmp" || return 1
    if ! grep -q "oh-my-zsh" "$tmp"; then
        log_error "Downloaded script does not look like the Oh My Zsh installer; aborting."
        return 1
    fi

    log_info "Running the Oh My Zsh installer (unattended)..."
    local had_zshrc=false
    [[ -f "$HOME/.zshrc" ]] && had_zshrc=true
    if ! RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh "$tmp" --unattended; then
        log_error "Oh My Zsh installation failed."
        return 1
    fi
    if [[ "$had_zshrc" == false && -f "$HOME/.zshrc" ]]; then
        # Consumed by configure-shell.sh (deploy_zsh_config).
        # shellcheck disable=SC2034
        OMZ_CREATED_ZSHRC=true
    fi

    omz_installed || { log_error "Oh My Zsh installer finished but $(omz_dir) is incomplete."; return 1; }
    log_success "Oh My Zsh installed."
}
