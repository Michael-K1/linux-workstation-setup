# functions.zsh - managed by linux-workstation-setup
# Custom shell functions.

# mkcd <dir> - create a directory (incl. parents) and cd into it.
mkcd() {
  mkdir -p -- "$1" && cd -- "$1" || return
}

# up [n] - go up n directories (default 1).
up() {
  local levels=${1:-1} path=""
  while (( levels-- > 0 )); do
    path+="../"
  done
  cd "$path" || return
}

# extract <archive> - extract common archive formats.
extract() {
  if [[ ! -f "$1" ]]; then
    echo "extract: '$1' is not a file" >&2
    return 1
  fi
  case "$1" in
    *.tar.bz2|*.tbz2) tar xjf "$1" ;;
    *.tar.gz|*.tgz)   tar xzf "$1" ;;
    *.tar.xz)         tar xJf "$1" ;;
    *.tar)            tar xf "$1" ;;
    *.zip)            unzip "$1" ;;
    *.gz)             gunzip "$1" ;;
    *.bz2)            bunzip2 "$1" ;;
    *.xz)             unxz "$1" ;;
    *) echo "extract: unsupported archive type: $1" >&2; return 1 ;;
  esac
}
