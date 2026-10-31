# aliases.zsh - managed by linux-workstation-setup
#
# Custom aliases ONLY. Everything already provided by Oh My Zsh is
# intentionally absent here, because this file loads AFTER Oh My Zsh
# and would silently shadow it. Run `alias` to see what you have.
#
# Already covered by Oh My Zsh - do not redefine:
#   Navigation:  auto_cd is enabled ('..' just works), '...'='../..', etc.
#   Listing:     l='ls -lah'  ll='ls -lh'  la='ls -lAh'  lsa='ls -lah'
#   Git plugin:  gst='git status'  gl='git pull'  gp='git push'
#                gc='git commit --verbose'  gco='git checkout'  gd='git diff'
#                ... and ~190 more (see: alias | grep "^g")
#
# Note: 'gs' is deliberately not aliased to 'git status' - Oh My Zsh uses
# 'gst' instead because 'gs' is the Ghostscript binary.

# Docker (not provided by Oh My Zsh by default)
alias dps="docker ps"
alias dcu="docker compose up -d"
alias dcd="docker compose down"

# Add your own aliases below, or in ~/.zshrc.local for machine-specific ones.
