# exports.zsh - managed by linux-workstation-setup
# Environment variables and PATH modifications.

# User-level binaries (Starship is installed here on non-Arch systems).
if [[ -d "$HOME/.local/bin" && ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
  export PATH="$HOME/.local/bin:$PATH"
fi

# Preferred editor (override in ~/.zshrc.local if desired).
if [[ -z "${EDITOR:-}" ]]; then
  if command -v nvim >/dev/null 2>&1; then
    export EDITOR="nvim"
  elif command -v vim >/dev/null 2>&1; then
    export EDITOR="vim"
  else
    export EDITOR="nano"
  fi
fi

# Sensible history defaults.
export HISTSIZE=50000
export SAVEHIST=50000
