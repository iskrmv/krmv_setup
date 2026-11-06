# ~/.config/fish/conf.d/krmv-aliases.fish (installed by krmv-setup)
alias pacman 'sudo pacman'
alias yoink 'yay -S'
alias yeet 'yay -Rns'
alias yago 'yay -Ss'
alias sweep 'bash ~/.config/hypr/scripts/cleanup.sh'
alias sudogui 'sh ~/.config/hypr/scripts/sudogui.sh'
alias vim 'nvim'
alias winfo 'sh ~/.config/hypr/scripts/window-info.sh'

# fastfetch greets you when a terminal opens
if status is-interactive; and command -sq fastfetch
    function fish_greeting
        fastfetch
    end
end
