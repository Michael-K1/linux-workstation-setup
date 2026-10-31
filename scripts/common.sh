# shellcheck shell=bash
# ============================================================
# common.sh - shared logging, prompting and utility functions.
# Sourced by install.sh; not meant to be executed directly.
# ============================================================

# Marker string used to recognize files deployed by this project.
readonly LWS_MARKER="managed by linux-workstation-setup"

# ---------- Colors (only when stdout is a terminal) ----------
if [[ -t 1 ]]; then
    C_RED=$'\033[0;31m'
    C_GREEN=$'\033[0;32m'
    C_YELLOW=$'\033[0;33m'
    C_BLUE=$'\033[0;34m'
    C_BOLD=$'\033[1m'
    C_RESET=$'\033[0m'
else
    C_RED="" C_GREEN="" C_YELLOW="" C_BLUE="" C_BOLD="" C_RESET=""
fi

# ---------- Logging ----------
log_info()    { printf '%b\n' "${C_BLUE}[INFO]${C_RESET} $*"; }
log_success() { printf '%b\n' "${C_GREEN}[ OK ]${C_RESET} $*"; }
log_warn()    { printf '%b\n' "${C_YELLOW}[WARN]${C_RESET} $*" >&2; }
log_error()   { printf '%b\n' "${C_RED}[FAIL]${C_RESET} $*" >&2; }
log_step()    { printf '\n%b\n' "${C_BOLD}==> $*${C_RESET}"; }

die() {
    log_error "$*"
    exit 1
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# ---------- Interaction ----------

# ask_yes_no "question" [default: y|n]
# Returns 0 for yes, 1 for no.
# In non-interactive mode (or when all defaults are accepted) the
# default answer is used without prompting.
ask_yes_no() {
    local question=$1 default=${2:-y} hint answer
    if [[ "${NON_INTERACTIVE:-false}" == true || "${ASSUME_YES:-false}" == true ]]; then
        [[ "$default" == y ]]
        return
    fi
    if [[ "$default" == y ]]; then hint="[Y/n]"; else hint="[y/N]"; fi
    while true; do
        read -r -p "${question} ${hint} " answer || answer=""
        answer=${answer,,}
        [[ -z "$answer" ]] && answer=$default
        case "$answer" in
            y|yes) return 0 ;;
            n|no)  return 1 ;;
            *) echo "Please answer 'y' or 'n'." ;;
        esac
    done
}

# ask_choice "question" "default" option...
# Prints the chosen option on stdout. Accepts the option number or its name.
ask_choice() {
    local question=$1 default=$2
    shift 2
    local options=("$@") i answer
    if [[ "${NON_INTERACTIVE:-false}" == true || "${ASSUME_YES:-false}" == true ]]; then
        printf '%s\n' "$default"
        return
    fi
    printf '%s\n' "$question" >&2
    for i in "${!options[@]}"; do
        printf '  %d) %s\n' "$((i + 1))" "${options[$i]}" >&2
    done
    while true; do
        read -r -p "Choice [default: ${default}]: " answer || answer=""
        if [[ -z "$answer" ]]; then
            printf '%s\n' "$default"
            return
        fi
        if [[ "$answer" =~ ^[0-9]+$ ]] && ((answer >= 1 && answer <= ${#options[@]})); then
            printf '%s\n' "${options[$((answer - 1))]}"
            return
        fi
        for i in "${options[@]}"; do
            if [[ "${answer,,}" == "${i,,}" ]]; then
                printf '%s\n' "$i"
                return
            fi
        done
        echo "Invalid choice, try again." >&2
    done
}

# ---------- Privileges ----------

# as_root cmd [args...] - run a command with root privileges.
# Uses sudo unless we already are root. Never assumes root.
as_root() {
    if [[ "$EUID" -eq 0 ]]; then
        "$@"
    elif command_exists sudo; then
        sudo "$@"
    else
        log_error "Root privileges are required for: $* (sudo is not available)"
        return 1
    fi
}

# ---------- Files ----------

# backup_file <path>
# Creates <path>.bak.<timestamp> next to the original. No-op if missing.
backup_file() {
    local file=$1 backup
    [[ -e "$file" ]] || return 0
    backup="${file}.bak.$(date +%Y%m%d-%H%M%S)"
    cp -a -- "$file" "$backup"
    log_info "Backup created: ${backup}"
}

# file_is_managed <path> - true if the file was deployed by this project.
file_is_managed() {
    [[ -f "$1" ]] && grep -q "$LWS_MARKER" "$1"
}

# deploy_config_file <source> <destination>
# Idempotent: skips identical files, asks before replacing different ones,
# and always keeps a timestamped backup when replacing.
# In non-interactive mode, files NOT created by this project are never touched.
deploy_config_file() {
    local src=$1 dst=$2 label
    label=$(basename "$dst")
    if [[ -f "$dst" ]] && cmp -s "$src" "$dst"; then
        log_info "${label} is already up to date."
        return 0
    fi
    if [[ -f "$dst" ]]; then
        if [[ "${NON_INTERACTIVE:-false}" == true ]] && ! file_is_managed "$dst"; then
            log_warn "${dst} exists and was not created by this installer; leaving it untouched (non-interactive mode)."
            return 0
        fi
        if ! ask_yes_no "${dst} already exists and differs. Replace it (a timestamped backup will be kept)?" y; then
            log_info "Keeping existing ${label}."
            return 0
        fi
        backup_file "$dst"
    fi
    cp -- "$src" "$dst"
    log_success "Deployed ${label} -> ${dst}"
}

# ---------- Network ----------

# download_file <url> <destination>
download_file() {
    local url=$1 dest=$2
    if command_exists curl; then
        curl -fsSL --retry 2 --connect-timeout 15 -o "$dest" "$url"
    elif command_exists wget; then
        wget -q --timeout=15 -O "$dest" "$url"
    else
        log_error "Neither curl nor wget is available; cannot download ${url}"
        return 1
    fi
}

# download_script <url> <destination>
# Downloads and sanity-checks a shell script before it may be executed.
download_script() {
    local url=$1 dest=$2
    if ! download_file "$url" "$dest"; then
        log_error "Download failed: ${url}"
        return 1
    fi
    if [[ ! -s "$dest" ]] || ! head -n1 "$dest" | grep -q '^#!'; then
        log_error "Downloaded file does not look like a shell script: ${url}"
        return 1
    fi
}

# clone_repo <url> <destination>
# Shallow-clones a repository; skips if already cloned.
clone_repo() {
    local url=$1 dest=$2
    if [[ -d "${dest}/.git" ]]; then
        log_info "Already cloned: ${dest}"
        return 0
    fi
    if [[ -e "$dest" ]]; then
        log_warn "${dest} exists but is not a git repository; leaving it untouched."
        return 1
    fi
    if ! git clone --depth=1 --quiet "$url" "$dest"; then
        log_error "git clone failed: ${url}"
        return 1
    fi
    log_success "Cloned $(basename "$dest")."
}
