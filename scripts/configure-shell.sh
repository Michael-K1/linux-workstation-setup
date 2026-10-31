# shellcheck shell=bash
# ============================================================
# configure-shell.sh - default shell + modular Zsh configuration.
#
# Deploys:
#   ~/.zshrc                   (rendered from config/zsh/.zshrc with the
#                               selected theme and plugin list)
#   ~/.config/zsh/aliases.zsh
#   ~/.config/zsh/exports.zsh
#   ~/.config/zsh/functions.zsh
#   ~/.config/zsh/prompt.zsh   (generated for the selected prompt engine)
#
# All deployments go through deploy_config_file (idempotent, backed up,
# never overwrites foreign files without permission).
# ============================================================

# ---------- Default shell ----------

set_default_shell() {
    local zsh_path current_shell user_name
    user_name=${USER:-$(id -un)}
    zsh_path=$(command -v zsh) || { log_error "zsh not found; cannot change the default shell."; return 1; }
    current_shell=$(getent passwd "$user_name" | cut -d: -f7 || true)

    if [[ "$current_shell" == "$zsh_path" ]]; then
        log_success "Zsh is already the default shell."
        return 0
    fi

    if ! grep -qx "$zsh_path" /etc/shells 2>/dev/null; then
        log_warn "${zsh_path} is not listed in /etc/shells; chsh will likely refuse it."
    fi

    log_info "Changing default shell to ${zsh_path} (current: ${current_shell:-unknown})."

    if [[ "${NON_INTERACTIVE:-false}" == true ]]; then
        # chsh prompts for a password, which would hang automation; only try
        # passwordless sudo and otherwise explain what to run manually.
        if command_exists sudo && sudo -n true 2>/dev/null && sudo -n usermod -s "$zsh_path" "$user_name" 2>/dev/null; then
            log_success "Default shell changed to Zsh."
            return 0
        fi
        log_warn "Cannot change the shell without a password prompt in non-interactive mode."
        log_warn "Run manually: chsh -s ${zsh_path}"
        return 1
    fi

    if command_exists chsh; then
        if chsh -s "$zsh_path"; then
            log_success "Default shell changed to Zsh (takes effect on next login)."
            return 0
        fi
        log_warn "chsh failed; trying 'usermod' with sudo..."
    else
        log_warn "chsh is not available; trying 'usermod' with sudo..."
    fi

    if as_root usermod -s "$zsh_path" "$user_name"; then
        log_success "Default shell changed to Zsh (takes effect on next login)."
        return 0
    fi

    log_error "Could not change the default shell."
    if [[ "${IMMUTABLE:-false}" == true ]]; then
        log_warn "On OSTree-based systems try: sudo usermod -s ${zsh_path} ${user_name}  (or 'lchsh' on Fedora Atomic)."
    fi
    return 1
}

# ---------- Modular Zsh configuration ----------

# render_zshrc <output-file>
# Renders config/zsh/.zshrc with the selected theme and plugin list.
render_zshrc() {
    local out=$1 theme="robbyrussell" plugin_list="git"

    case "${PROMPT_ENGINE:-none}" in
        p10k)
            theme="powerlevel10k/powerlevel10k"
            ;;
        starship)
            theme="robbyrussell"  # placeholder; Starship takes over after OMZ loads
            ;;
        none)
            # Keep whatever theme the user currently has, if readable.
            if [[ -f "$HOME/.zshrc" ]]; then
                local current_theme
                current_theme=$(grep -m1 -oP '^ZSH_THEME="\K[^"]+' "$HOME/.zshrc" || true)
                [[ -n "$current_theme" ]] && theme=$current_theme
            fi
            ;;
    esac

    [[ "${PLUGIN_AUTOSUGGESTIONS:-false}" == true ]] && plugin_list+=" zsh-autosuggestions"
    # zsh-syntax-highlighting must be the last plugin, per its maintainers.
    [[ "${PLUGIN_SYNTAX_HIGHLIGHTING:-false}" == true ]] && plugin_list+=" zsh-syntax-highlighting"

    sed -e "s|^ZSH_THEME=.*|ZSH_THEME=\"${theme}\"|" \
        -e "s|^plugins=.*|plugins=(${plugin_list})|" \
        "${REPO_DIR}/config/zsh/.zshrc" > "$out"
}

# render_prompt_module <output-file>
# Generates ~/.config/zsh/prompt.zsh for the selected prompt engine.
# Exactly one engine is ever initialized (never both).
render_prompt_module() {
    local out=$1
    case "${PROMPT_ENGINE:-none}" in
        starship)
            cat > "$out" <<'EOF'
# prompt.zsh - managed by linux-workstation-setup
# Prompt engine: Starship (https://starship.rs)
# Loaded after Oh My Zsh; replaces the Oh My Zsh theme prompt.
if command -v starship >/dev/null 2>&1; then
    eval "$(starship init zsh)"
fi
EOF
            ;;
        p10k)
            cat > "$out" <<'EOF'
# prompt.zsh - managed by linux-workstation-setup
# Prompt engine: Powerlevel10k (theme is set via ZSH_THEME in ~/.zshrc).
# To customize, run `p10k configure` or edit ~/.p10k.zsh.
[[ -f "$HOME/.p10k.zsh" ]] && source "$HOME/.p10k.zsh"
EOF
            ;;
        *)
            return 1
            ;;
    esac
}

deploy_zsh_config() {
    local zsh_config_dir="$HOME/.config/zsh" tmp

    if ! omz_installed; then
        log_error "The .zshrc template loads Oh My Zsh; install Oh My Zsh before deploying the configuration."
        return 1
    fi

    mkdir -p "$zsh_config_dir"

    # Main entry point, rendered with theme + plugins.
    tmp=$(mktemp)
    # shellcheck disable=SC2064
    trap "rm -f '$tmp'" RETURN
    render_zshrc "$tmp"
    if [[ "${OMZ_CREATED_ZSHRC:-false}" == true ]] && ! cmp -s "$tmp" "$HOME/.zshrc"; then
        # The existing .zshrc is the stock template the OMZ installer created
        # moments ago in this very run; replacing it is safe (backup kept).
        backup_file "$HOME/.zshrc"
        cp -- "$tmp" "$HOME/.zshrc"
        log_success "Deployed .zshrc (replaced the stock Oh My Zsh template)."
    else
        deploy_config_file "$tmp" "$HOME/.zshrc" || return 1
    fi

    # Static modules.
    local module
    for module in aliases.zsh exports.zsh functions.zsh; do
        deploy_config_file "${REPO_DIR}/config/zsh/${module}" "${zsh_config_dir}/${module}" || return 1
    done

    # Prompt module, generated per selected engine.
    if [[ "${PROMPT_ENGINE:-none}" == "none" ]]; then
        log_info "Prompt engine unchanged; ~/.config/zsh/prompt.zsh was not modified."
    else
        render_prompt_module "$tmp"
        deploy_config_file "$tmp" "${zsh_config_dir}/prompt.zsh" || return 1
    fi

    log_success "Modular Zsh configuration deployed (local overrides: ~/.zshrc.local)."
}
