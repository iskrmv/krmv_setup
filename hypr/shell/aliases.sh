# shellcheck shell=sh
# ~/.config/hypr/shell/aliases.sh - sourced by bash and zsh (installed by krmv-setup)
alias pacman='sudo pacman'
alias yoink='yay -S'      # install
alias yeet='yay -Rns'     # remove (with dependencies and config files)
alias yago='yay -Ss'      # search
alias sweep='bash ~/.config/hypr/scripts/cleanup.sh'   # deep clean (sweep --all = everything)
alias sudogui='sh ~/.config/hypr/scripts/sudogui.sh'   # run GUI apps as root (sudogui ventoygui)
alias vim='nvim'
alias winfo='sh ~/.config/hypr/scripts/window-info.sh'   # sizes and positions of all windows (for bug reports)
