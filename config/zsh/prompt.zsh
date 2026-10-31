# prompt.zsh - managed by linux-workstation-setup
# Reference copy. The installer generates this module into
# ~/.config/zsh/prompt.zsh for the prompt engine you selected,
# so exactly one engine is ever initialized.
#
# Default: Starship.
if command -v starship >/dev/null 2>&1; then
    eval "$(starship init zsh)"
fi
