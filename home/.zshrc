# ~/.zshrc

# Show system info on new interactive shells (must run before p10k instant prompt)
[[ -o interactive ]] && command -v fastfetch >/dev/null && fastfetch

# Powerlevel10k instant prompt — keep near the top
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

export ZSH="$HOME/.oh-my-zsh"
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
export EDITOR=micro
export VISUAL=micro

ZSH_THEME="powerlevel10k/powerlevel10k"

# Oh My Zsh behavior
zstyle ':omz:update' mode reminder
COMPLETION_WAITING_DOTS="true"
HIST_STAMPS="yyyy-mm-dd"

# Extra completions must be on fpath before compinit (run by oh-my-zsh)
fpath+=${ZSH_CUSTOM:-$ZSH/custom}/plugins/zsh-completions/src

plugins=(
  git
  sudo                    # press Esc twice to prefix last command with sudo
  archlinux               # pacman/paru aliases (pacupg, pacin, ...)
  command-not-found
  extract                 # `x file.tar.gz` extracts any archive
  systemd                 # sc-status, sc-restart, scu-* for user services
  copypath                # copy current dir path to clipboard
  copyfile                # copyfile <file> copies its contents
  aliases                 # `als` lists all aliases
  dirhistory              # Alt+Left/Right back/forward, Alt+Up parent dir
  you-should-use          # reminds you when an alias exists
  fzf-tab                 # fzf menu for Tab completion; before autosuggestions
  zsh-autosuggestions
  zsh-syntax-highlighting
  history-substring-search # after syntax-highlighting; keep last
)

source $ZSH/oh-my-zsh.sh

# Up/Down search history for what's already typed
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down
bindkey -M emacs '^P' history-substring-search-up
bindkey -M emacs '^N' history-substring-search-down

# fzf-tab previews
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --icons --color=always $realpath'
zstyle ':fzf-tab:complete:z:*' fzf-preview 'eza -1 --icons --color=always $realpath'

# History
HISTSIZE=50000
SAVEHIST=50000
setopt HIST_IGNORE_ALL_DUPS HIST_IGNORE_SPACE HIST_REDUCE_BLANKS SHARE_HISTORY

# Modern CLI tools
source <(fzf --zsh)                      # Ctrl+R history, Ctrl+T files, Alt+C cd
eval "$(zoxide init zsh)"                # z <dir> jumps, zi picks interactively
export FZF_DEFAULT_COMMAND='fd --type f --hidden --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND='fd --type d --hidden --exclude .git'
export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border'
export FZF_CTRL_T_OPTS="--preview 'bat --color=always --style=numbers --line-range=:300 {}'"
export FZF_ALT_C_OPTS="--preview 'eza --tree --level=2 --icons --color=always {}'"
export MANPAGER="sh -c 'col -bx | bat -l man -p'"
export MANROFFOPT="-c"

# Aliases
alias ls='eza --icons --group-directories-first'
alias ll='eza -lah --icons --group-directories-first --git'
alias lt='eza --tree --level=2 --icons'
alias cat='bat --paging=never'
alias grep='grep --color=auto'
alias top='btop'
alias df='duf'
alias du='dust'
alias update='paru -Syu'
cleanup() {
  if pgrep -x 'pacman|paru' >/dev/null; then echo "pacman/paru is running, try later"; return 1; fi
  paru -c && sudo rm -rf /var/cache/pacman/pkg/download-*(N) && sudo pacman -Sc   # download-* = interrupted downloads
}
alias ff='fastfetch'

# Navigation
alias ..='cd ..'
alias ...='cd ../..'
mkcd() { mkdir -p "$1" && cd "$1"; }

# Ask before overwriting
alias cp='cp -i'
alias mv='mv -i'

# Shell
alias reload='exec zsh'
alias zshrc='$EDITOR ~/.zshrc'

# Arch
alias orphans='pacman -Qdtq'
alias paccache-clean='sudo paccache -rk2'
alias recent='expac --timefmt="%F %T" "%l %n" | sort | tail -30'

# System
alias errors='journalctl -p 3 -xb'
alias failed='systemctl --failed; systemctl --user --failed'
alias ports='ss -tulpn'
alias myip='curl -s ifconfig.me; echo'

# Powerlevel10k config — run `p10k configure` to customize
[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh
alias mirrors='sudo cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak && sudo reflector --verbose --country SA,AE,DE --protocol https --age 12 --latest 30 --sort rate --number 10 --download-timeout 5 --save /etc/pacman.d/mirrorlist && cat /etc/pacman.d/mirrorlist && sudo pacman -Syy'
source /usr/share/nvm/init-nvm.sh

#THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!!
export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"
