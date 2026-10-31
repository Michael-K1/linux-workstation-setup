#!/usr/bin/env bash
# ============================================================
# Linux Workstation Setup - interactive bootstrap installer
#
# Usage: ./install.sh [options]      (see --help)
#
# Safe to run repeatedly: every step detects existing installations,
# backs up configuration files before changing them, and never
# overwrites foreign files without permission.
# ============================================================

set -Eeuo pipefail

REPO_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
readonly REPO_DIR

# shellcheck source=scripts/common.sh
source "${REPO_DIR}/scripts/common.sh"
# shellcheck source=scripts/detect-distro.sh
source "${REPO_DIR}/scripts/detect-distro.sh"
# shellcheck source=scripts/install-packages.sh
source "${REPO_DIR}/scripts/install-packages.sh"
# shellcheck source=scripts/install-zsh.sh
source "${REPO_DIR}/scripts/install-zsh.sh"
# shellcheck source=scripts/install-ohmyzsh.sh
source "${REPO_DIR}/scripts/install-ohmyzsh.sh"
# shellcheck source=scripts/install-prompt.sh
source "${REPO_DIR}/scripts/install-prompt.sh"
# shellcheck source=scripts/install-plugins.sh
source "${REPO_DIR}/scripts/install-plugins.sh"
# shellcheck source=scripts/install-fonts.sh
source "${REPO_DIR}/scripts/install-fonts.sh"
# shellcheck source=scripts/configure-shell.sh
source "${REPO_DIR}/scripts/configure-shell.sh"

trap 'log_error "Unexpected error on line ${LINENO}. See the messages above."' ERR

# ---------- CLI ----------

NON_INTERACTIVE=false
ASSUME_YES=false
SETTINGS_FILE="${REPO_DIR}/settings.conf"
CLI_OVERRIDES=()

usage() {
    cat <<EOF
Linux Workstation Setup

Usage: ./install.sh [options]

Options:
  -h, --help             Show this help and exit.
  -y, --yes              Accept all recommended defaults (skips questions
                         and the final confirmation, still prints a summary).
  -n, --non-interactive  Fully unattended mode: apply the settings file and
                         command-line overrides without asking anything.
                         Foreign config files are never overwritten.
      --settings FILE    Use an alternative settings file
                         (default: settings.conf in the repository).
      --prompt ENGINE    Select the prompt engine: starship | p10k | none.
      --set KEY=VALUE    Override any setting (repeatable), e.g.
                         --set INSTALL_MESLO_NERD_FONT=false

Examples:
  ./install.sh                         Interactive installation (recommended).
  ./install.sh -y                      Accept all defaults.
  ./install.sh -n --prompt p10k        Unattended, with Powerlevel10k.
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help) usage; exit 0 ;;
            -y|--yes) ASSUME_YES=true ;;
            -n|--non-interactive) NON_INTERACTIVE=true ;;
            --settings)
                [[ $# -ge 2 ]] || die "--settings requires a file argument."
                SETTINGS_FILE=$2; shift ;;
            --prompt)
                [[ $# -ge 2 ]] || die "--prompt requires an argument (starship | p10k | none)."
                CLI_OVERRIDES+=("PROMPT_ENGINE=$2"); shift ;;
            --set)
                [[ $# -ge 2 ]] || die "--set requires a KEY=VALUE argument."
                CLI_OVERRIDES+=("$2"); shift ;;
            *) die "Unknown option: $1 (see --help)" ;;
        esac
        shift
    done
}

load_settings() {
    [[ -f "$SETTINGS_FILE" ]] || die "Settings file not found: ${SETTINGS_FILE}"
    # shellcheck source=settings.conf
    source "$SETTINGS_FILE"

    local kv key value
    for kv in ${CLI_OVERRIDES[@]+"${CLI_OVERRIDES[@]}"}; do
        [[ "$kv" =~ ^[A-Z_][A-Z0-9_]*=.*$ ]] || die "Invalid --set value: '${kv}' (expected KEY=VALUE)"
        key=${kv%%=*}
        value=${kv#*=}
        printf -v "$key" '%s' "$value"
    done

    case "${PROMPT_ENGINE:-}" in
        starship|p10k|none) ;;
        *) die "Invalid PROMPT_ENGINE: '${PROMPT_ENGINE:-}' (expected: starship | p10k | none)" ;;
    esac
}

# ---------- Interactive flow ----------

show_welcome() {
    printf '%b\n' "${C_BOLD}"
    cat <<'EOF'
============================================================
          Linux Workstation Setup
============================================================
EOF
    printf '%b\n' "${C_RESET}"
    log_info "Bootstraps a consistent Zsh environment: Zsh, Oh My Zsh,"
    log_info "a prompt engine (Starship or Powerlevel10k), Meslo Nerd Font,"
    log_info "plugins and a modular Zsh configuration."
    log_info "Safe to re-run at any time; existing files are backed up."
    echo
}

# status_of <label> <check...>
status_of() {
    local label=$1; shift
    if "$@"; then
        printf '  %-28s %s\n' "$label" "${C_GREEN}installed${C_RESET}"
    else
        printf '  %-28s %s\n' "$label" "${C_YELLOW}not installed${C_RESET}"
    fi
}

default_shell_is_zsh() {
    local zsh_path
    zsh_path=$(command -v zsh 2>/dev/null) || return 1
    [[ "$(getent passwd "${USER:-$(id -un)}" | cut -d: -f7)" == "$zsh_path" ]]
}

show_component_status() {
    log_step "Current component status"
    status_of "Zsh"                      zsh_installed
    status_of "Oh My Zsh"                omz_installed
    status_of "Starship"                 starship_installed
    status_of "Powerlevel10k"            p10k_installed
    status_of "zsh-autosuggestions"      plugin_installed zsh-autosuggestions
    status_of "zsh-syntax-highlighting"  plugin_installed zsh-syntax-highlighting
    status_of "MesloLGS Nerd Font"       meslo_font_installed
    status_of "Zsh as default shell"     default_shell_is_zsh
}

interactive_configure() {
    log_step "Component selection"
    log_info "Answer the questions below, or press Enter to accept the recommended default."
    echo

    if ! ask_yes_no "Configure the shell environment (Zsh and related tools)?" y; then
        log_info "Nothing selected. Exiting without changes."
        exit 0
    fi

    # --- Zsh ---
    if zsh_installed; then
        log_info "Zsh is already installed; it will only be verified."
        INSTALL_ZSH=true
    elif ask_yes_no "Install Zsh?" "$(bool_default "$INSTALL_ZSH")"; then
        INSTALL_ZSH=true
    else
        INSTALL_ZSH=false
    fi

    if [[ "$INSTALL_ZSH" == true ]] || zsh_installed; then
        if default_shell_is_zsh; then
            SET_DEFAULT_SHELL=false
            log_info "Zsh is already your default shell."
        elif ask_yes_no "Set Zsh as your default shell?" "$(bool_default "$SET_DEFAULT_SHELL")"; then
            SET_DEFAULT_SHELL=true
        else
            SET_DEFAULT_SHELL=false
        fi
    else
        SET_DEFAULT_SHELL=false
    fi

    # --- Oh My Zsh ---
    if omz_installed; then
        log_info "Oh My Zsh is already installed; it will not be reinstalled."
        INSTALL_OH_MY_ZSH=true
    elif ask_yes_no "Install Oh My Zsh (plugin/theme framework for Zsh)?" "$(bool_default "$INSTALL_OH_MY_ZSH")"; then
        INSTALL_OH_MY_ZSH=true
    else
        INSTALL_OH_MY_ZSH=false
    fi

    # --- Prompt engine ---
    echo
    log_info "Prompt engines:"
    log_info "  starship - cross-shell, fast (Rust), TOML config. Recommended."
    log_info "  p10k     - Powerlevel10k: Zsh-only, highly customizable, interactive wizard."
    log_warn "  Note: Powerlevel10k is in life-support mode (no new features per its"
    log_warn "  maintainer). It still works fine, but Starship is the recommended default."
    if starship_installed; then log_info "Detected: Starship is already installed."; fi
    if p10k_installed; then log_info "Detected: Powerlevel10k is already installed."; fi
    PROMPT_ENGINE=$(ask_choice "Which prompt engine do you want to use?" "${PROMPT_ENGINE}" \
        "starship" "p10k" "none")
    if [[ "$PROMPT_ENGINE" == "p10k" && "$INSTALL_OH_MY_ZSH" != true ]]; then
        log_warn "Powerlevel10k requires Oh My Zsh, which you chose not to install; keeping the current prompt instead."
        PROMPT_ENGINE="none"
    fi

    # --- Font ---
    echo
    if meslo_font_installed; then
        log_info "MesloLGS NF is already installed."
        INSTALL_MESLO_NERD_FONT=false
    elif ask_yes_no "Install Meslo Nerd Font (MesloLGS NF, recommended for both prompt engines)?" "$(bool_default "$INSTALL_MESLO_NERD_FONT")"; then
        INSTALL_MESLO_NERD_FONT=true
    else
        INSTALL_MESLO_NERD_FONT=false
    fi

    # --- Plugins ---
    echo
    log_info "The Oh My Zsh 'git' plugin (aliases/functions) stays enabled by default."
    if ask_yes_no "Install zsh-autosuggestions (history-based command suggestions)?" "$(bool_default "$PLUGIN_AUTOSUGGESTIONS")"; then
        PLUGIN_AUTOSUGGESTIONS=true
    else
        PLUGIN_AUTOSUGGESTIONS=false
    fi
    if ask_yes_no "Install zsh-syntax-highlighting (live command highlighting)?" "$(bool_default "$PLUGIN_SYNTAX_HIGHLIGHTING")"; then
        PLUGIN_SYNTAX_HIGHLIGHTING=true
    else
        PLUGIN_SYNTAX_HIGHLIGHTING=false
    fi

    # --- Config deployment ---
    echo
    if ask_yes_no "Deploy the modular Zsh configuration (~/.zshrc + ~/.config/zsh/*.zsh)?" "$(bool_default "$DEPLOY_ZSH_CONFIG")"; then
        DEPLOY_ZSH_CONFIG=true
    else
        DEPLOY_ZSH_CONFIG=false
    fi
}

# bool_default <true|false> -> y|n   (maps settings to ask_yes_no defaults)
bool_default() {
    [[ "$1" == true ]] && printf 'y' || printf 'n'
}

summary_line() {
    local label=$1 enabled=$2 note=${3:-}
    if [[ "$enabled" == true ]]; then
        printf '  %-34s %s %s\n' "$label" "${C_GREEN}yes${C_RESET}" "$note"
    else
        printf '  %-34s %s %s\n' "$label" "${C_YELLOW}skip${C_RESET}" "$note"
    fi
}

show_summary() {
    log_step "Installation summary"
    summary_line "Install Zsh"                     "$INSTALL_ZSH" "$(zsh_installed && echo '(already installed, verify only)')"
    summary_line "Set Zsh as default shell"        "$SET_DEFAULT_SHELL"
    summary_line "Install Oh My Zsh"               "$INSTALL_OH_MY_ZSH" "$(omz_installed && echo '(already installed)')"
    printf '  %-34s %s\n' "Prompt engine" "${C_BOLD}${PROMPT_ENGINE}${C_RESET}"
    summary_line "Install MesloLGS Nerd Font"      "$INSTALL_MESLO_NERD_FONT" "$(meslo_font_installed && echo '(already installed)')"
    summary_line "Plugin: git (built-in)"          true
    summary_line "Plugin: zsh-autosuggestions"     "$PLUGIN_AUTOSUGGESTIONS"
    summary_line "Plugin: zsh-syntax-highlighting" "$PLUGIN_SYNTAX_HIGHLIGHTING"
    summary_line "Deploy modular Zsh config"       "$DEPLOY_ZSH_CONFIG"
    echo
    if [[ "$PKG_MANAGER" == "rpm-ostree" ]] && ! zsh_installed && [[ "$INSTALL_ZSH" == true ]]; then
        log_warn "Bazzite: Zsh will be layered with rpm-ostree and requires a reboot."
        log_warn "Steps that depend on Zsh will be skipped until you reboot and re-run this installer."
    fi
}

# ---------- Execution ----------

RESULT_OK=()
RESULT_SKIP=()
RESULT_FAIL=()

run_step() {
    local label=$1; shift
    log_step "$label"
    if "$@"; then
        RESULT_OK+=("$label")
    else
        RESULT_FAIL+=("$label")
        log_error "Step failed: ${label}"
    fi
}

skip_step() {
    local label=$1 reason=$2
    RESULT_SKIP+=("${label} (${reason})")
    log_info "Skipping ${label}: ${reason}"
}

run_installation() {
    # 1. Zsh
    if [[ "$INSTALL_ZSH" == true ]]; then
        run_step "Install Zsh" install_zsh
    else
        skip_step "Install Zsh" "not selected"
    fi

    # 2. Oh My Zsh (requires a working zsh binary)
    if [[ "$INSTALL_OH_MY_ZSH" == true ]]; then
        if zsh_installed; then
            run_step "Install Oh My Zsh" install_oh_my_zsh
        else
            skip_step "Install Oh My Zsh" "zsh is not available yet (on Bazzite: reboot, then re-run)"
        fi
    else
        skip_step "Install Oh My Zsh" "not selected"
    fi

    # 3. Prompt engine
    if [[ "$PROMPT_ENGINE" == "none" ]]; then
        skip_step "Install prompt engine" "keeping current prompt"
    elif [[ "$PROMPT_ENGINE" == "p10k" ]] && ! omz_installed; then
        skip_step "Install prompt engine (p10k)" "Oh My Zsh is not available"
    else
        run_step "Install prompt engine (${PROMPT_ENGINE})" install_prompt_engine
    fi

    # 4. Font
    if [[ "$INSTALL_MESLO_NERD_FONT" == true ]]; then
        run_step "Install MesloLGS Nerd Font" install_meslo_font
    else
        skip_step "Install MesloLGS Nerd Font" "not selected or already installed"
    fi

    # 5. Plugins
    if [[ "$PLUGIN_AUTOSUGGESTIONS" == true || "$PLUGIN_SYNTAX_HIGHLIGHTING" == true ]]; then
        if omz_installed; then
            run_step "Install Zsh plugins" install_plugins
        else
            skip_step "Install Zsh plugins" "Oh My Zsh is not available"
        fi
    else
        skip_step "Install Zsh plugins" "none selected"
    fi

    # 6. Modular configuration
    if [[ "$DEPLOY_ZSH_CONFIG" == true ]]; then
        if omz_installed; then
            run_step "Deploy modular Zsh configuration" deploy_zsh_config
        else
            skip_step "Deploy modular Zsh configuration" "Oh My Zsh is not available"
        fi
    else
        skip_step "Deploy modular Zsh configuration" "not selected"
        if [[ "$PROMPT_ENGINE" == "starship" ]]; then
            log_info "To activate Starship manually, add to your .zshrc:  eval \"\$(starship init zsh)\""
        elif [[ "$PROMPT_ENGINE" == "p10k" ]]; then
            log_info "To activate Powerlevel10k manually, set in your .zshrc:  ZSH_THEME=\"powerlevel10k/powerlevel10k\""
        fi
    fi

    # 7. Default shell (last: zsh may have been installed in step 1)
    if [[ "$SET_DEFAULT_SHELL" == true ]]; then
        if zsh_installed; then
            run_step "Set Zsh as default shell" set_default_shell
        else
            skip_step "Set Zsh as default shell" "zsh is not available yet"
        fi
    else
        skip_step "Set Zsh as default shell" "not selected"
    fi
}

show_results() {
    log_step "Results"
    local item
    for item in ${RESULT_OK[@]+"${RESULT_OK[@]}"}; do
        log_success "$item"
    done
    for item in ${RESULT_SKIP[@]+"${RESULT_SKIP[@]}"}; do
        log_info "Skipped: $item"
    done
    for item in ${RESULT_FAIL[@]+"${RESULT_FAIL[@]}"}; do
        log_error "$item"
    done

    echo
    if [[ "$REBOOT_REQUIRED" == true ]]; then
        log_warn "A reboot is required to activate the layered rpm-ostree packages."
        log_warn "After rebooting, re-run ./install.sh to complete the remaining steps."
    fi
    log_step "Next steps"
    log_info "1. Restart your terminal or run: exec zsh"
    log_info "2. Set your terminal emulator's font to 'MesloLGS NF'."
    case "$PROMPT_ENGINE" in
        starship) log_info "3. Customize Starship via ~/.config/starship.toml (https://starship.rs/config/)." ;;
        p10k)     log_info "3. Powerlevel10k's wizard starts on first launch; re-run anytime with: p10k configure" ;;
    esac

    [[ ${#RESULT_FAIL[@]} -eq 0 ]]
}

# ---------- Main ----------

main() {
    parse_args "$@"
    load_settings

    show_welcome

    log_step "System detection"
    detect_distro
    print_system_info
    confirm_distro_support || exit 1

    show_component_status

    if [[ "$NON_INTERACTIVE" == false && "$ASSUME_YES" == false ]]; then
        interactive_configure
    else
        log_info "Using defaults from ${SETTINGS_FILE}$( [[ ${#CLI_OVERRIDES[@]} -gt 0 ]] && echo ' (with command-line overrides)')."
    fi

    show_summary

    if [[ "$NON_INTERACTIVE" == false && "$ASSUME_YES" == false ]]; then
        if ! ask_yes_no "Proceed with the installation?" y; then
            log_info "Aborted. No changes were made."
            exit 0
        fi
    fi

    ensure_base_tools || exit 1
    run_installation

    if show_results; then
        exit 0
    else
        exit 1
    fi
}

main "$@"
