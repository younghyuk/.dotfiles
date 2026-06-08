# starship
eval "$(starship init zsh)"

# zsh-completions
if type brew &>/dev/null; then
  FPATH=$(brew --prefix)/share/zsh-completions:$FPATH

  autoload -Uz compinit
  compinit
fi

# zsh-autosuggestions
source $(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh

# zsh-syntax-highlighting
source $(brew --prefix)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# 1password
export SSH_AUTH_SOCK=~/Library/Group\ Containers/2BUA8C4S2C.com.1password/t/agent.sock
export OP_BIOMETRIC_UNLOCK_ENABLED=true
[[ -f ~/.config/op/plugins.sh ]] && source ~/.config/op/plugins.sh

# zoxide
eval "$(zoxide init zsh)"

# eza
alias ls="eza --icons"
alias ll="eza -l --icons"
alias la="eza -la --icons"
alias lt="eza -a --tree --icons"

# fnm
eval "$(fnm env --use-on-cd --version-file-strategy=recursive --shell zsh)"

# pnpm
export PNPM_HOME="/Users/ethan/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME/bin:"*) ;;
  *) export PATH="$PNPM_HOME/bin:$PNPM_HOME:$PATH" ;;
esac
# pnpm end

# mysql-client
export PATH="/opt/homebrew/opt/mysql-client/bin:$PATH"

# 시크릿 (~/.zsh_secrets, git 관리 안 됨)
[[ -f ~/.zsh_secrets ]] && source ~/.zsh_secrets

# claude
export PATH="$HOME/.local/bin:$PATH"
alias cc='claude --enable-auto-mode'
alias ccd='claude --dangerously-skip-permissions'

# bun completions
[ -s "/Users/ethan/.bun/_bun" ] && source "/Users/ethan/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# lazygit
alias lzg='lazygit'

# lazydocker
alias lzd='lazydocker'

# sentry
fpath=("/Users/ethan/.local/share/zsh/site-functions" $fpath)
