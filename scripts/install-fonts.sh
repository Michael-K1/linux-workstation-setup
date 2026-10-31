# shellcheck shell=bash
# ============================================================
# install-fonts.sh - MesloLGS NF (Meslo Nerd Font) installation.
#
# Installs the four variants recommended by Powerlevel10k into
# ~/.local/share/fonts/MesloLGS-NF/. The same font also covers
# Starship, so no reinstall is needed when switching engines.
# ============================================================

readonly FONT_BASE_URL="https://github.com/romkatv/powerlevel10k-media/raw/master"
readonly FONT_VARIANTS=("Regular" "Bold" "Italic" "Bold Italic")

font_dir() {
    printf '%s' "$HOME/.local/share/fonts/MesloLGS-NF"
}

meslo_font_installed() {
    local variant
    for variant in "${FONT_VARIANTS[@]}"; do
        [[ -s "$(font_dir)/MesloLGS NF ${variant}.ttf" ]] || return 1
    done
}

install_meslo_font() {
    local dir variant file dest url tmp failed=0 downloaded=0
    dir=$(font_dir)

    if meslo_font_installed; then
        log_success "MesloLGS NF is already installed in ${dir}."
        print_font_notes
        return 0
    fi

    mkdir -p "$dir"
    for variant in "${FONT_VARIANTS[@]}"; do
        file="MesloLGS NF ${variant}.ttf"
        dest="${dir}/${file}"
        if [[ -s "$dest" ]]; then
            log_info "Already present: ${file}"
            continue
        fi
        url="${FONT_BASE_URL}/MesloLGS%20NF%20${variant// /%20}.ttf"
        tmp=$(mktemp)
        log_info "Downloading ${file} ..."
        if download_file "$url" "$tmp" && [[ "$(head -c4 "$tmp" | od -An -tx1 | tr -d ' \n')" == "00010000" ]]; then
            mv -- "$tmp" "$dest"
            downloaded=$((downloaded + 1))
        else
            log_error "Failed to download a valid TTF for: ${file}"
            rm -f -- "$tmp"
            failed=1
        fi
    done

    if [[ "$failed" -eq 1 ]]; then
        log_error "Some font files could not be installed; re-run the installer to retry."
        return 1
    fi

    if [[ "$downloaded" -gt 0 ]]; then
        if command_exists fc-cache; then
            log_info "Refreshing the font cache..."
            fc-cache -f "$dir" >/dev/null 2>&1 || log_warn "fc-cache returned an error; the font may still work after re-login."
        else
            log_warn "fontconfig (fc-cache) not found; the font cache was not refreshed."
            log_warn "Your desktop environment may pick up the font after re-login."
        fi
    fi

    log_success "MesloLGS NF installed in ${dir}."
    print_font_notes
}

print_font_notes() {
    log_info "Note: set your terminal emulator's font to 'MesloLGS NF' manually (this cannot be automated reliably)."
    log_info "Note: when working over SSH, the font must be installed on your LOCAL machine's terminal, not the remote server."
}
