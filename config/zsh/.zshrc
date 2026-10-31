# ============================================================
# ~/.zshrc - managed by linux-workstation-setup
# Based on the standard Oh My Zsh template.
#
# Put machine-specific tweaks in ~/.zshrc.local (loaded last,
# never touched by the installer) or add modules under
# ~/.config/zsh/*.zsh (loaded below).
# ============================================================

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Harmless no-op unless Powerlevel10k is the active theme.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Theme - managed by the installer.
# Powerlevel10k sets "powerlevel10k/powerlevel10k" here; with Starship the
# theme below is only a fallback, since Starship takes over after Oh My Zsh.
ZSH_THEME="robbyrussell"

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior.
# zstyle ':omz:update' mode disabled  # disable automatic updates
# zstyle ':omz:update' mode auto      # update automatically without asking
zstyle ':omz:update' mode reminder    # just remind me to update when it's time

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to change the command execution
# timestamp shown in the history command output.
# HIST_STAMPS="yyyy-mm-dd"

# Plugins - managed by the installer.
# Note: zsh-syntax-highlighting must remain the LAST entry.
plugins=(git)

source $ZSH/oh-my-zsh.sh

# ------------------------------------------------------------
# Modular custom configuration (~/.config/zsh/*.zsh)
# Loaded alphabetically; prompt.zsh therefore loads last.
# The (N) glob qualifier makes the loop a no-op when empty.
# ------------------------------------------------------------
for config_file in "$HOME/.config/zsh/"*.zsh(N); do
  [[ -f "$config_file" ]] && source "$config_file"
done
unset config_file

# Machine-local overrides (optional, never managed by the installer).
[[ -f "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"
