if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

if [[ -d /Library/Frameworks/Python.framework/Versions/3.11/bin ]]; then
  path=(/Library/Frameworks/Python.framework/Versions/3.11/bin $path)
fi

if [[ -d "$HOME/Library/Application Support/JetBrains/Toolbox/scripts" ]]; then
  path+=("$HOME/Library/Application Support/JetBrains/Toolbox/scripts")
fi

export PATH
