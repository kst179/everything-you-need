#!/usr/bin/env sh
set -eu

# ---------------- CONFIG ----------------
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
PLUGINS_DIR="$ZSH_CUSTOM/plugins"

# Keep as space-separated (easier to loop + avoids blank lines)
PLUGINS="git thefuck sudo zsh-autosuggestions zsh-completions zsh-history-substring-search fast-syntax-highlighting virtualenv"
# ----------------------------------------

say() { printf "%s\n" "$*"; }

have() { command -v "$1" >/dev/null 2>&1; }

is_macos() { [ "$(uname -s)" = "Darwin" ]; }

# portable in-place edit (GNU/BSD sed)
sedi() {
  # usage: sedi 's/foo/bar/' file
  if is_macos; then
    sed -i '' "$1" "$2"
  else
    sed -i "$1" "$2"
  fi
}

# -------------- Package install helpers --------------
install_pkgs_linux() {
  if have apt; then
    sudo apt update
    sudo apt install -y git zsh curl python3 python3-pip
  elif have dnf; then
    sudo dnf install -y git zsh curl python3 python3-pip
  elif have pacman; then
    sudo pacman -Sy --noconfirm git zsh curl python python-pip
  else
    say "⚠️ No supported Linux package manager detected. Assuming deps exist."
  fi
}

install_pkgs_macos() {
  if ! have brew; then
    say "⚠️ Homebrew not found. Install it first: https://brew.sh"
    say "   Continuing, but thefuck/uv installs may fall back to python installer."
  else
    brew install git zsh curl python || true
  fi
}

install_prereqs() {
  say "==> Installing prerequisites"
  if is_macos; then
    install_pkgs_macos
  else
    install_pkgs_linux
  fi
}

# -------------- Oh My Zsh --------------
install_ohmyzsh() {
  say "==> Installing Oh My Zsh"
  if [ ! -d "$HOME/.oh-my-zsh" ]; then
    RUNZSH=no CHSH=no sh -c \
      "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  else
    say "Oh My Zsh already installed"
  fi
}

# -------------- Plugins --------------
install_plugin() {
  name="$1"
  repo="$2"
  if [ ! -d "$PLUGINS_DIR/$name" ]; then
    git clone --depth=1 "$repo" "$PLUGINS_DIR/$name"
  else
    say "  - $name already installed"
  fi
}

install_plugins() {
  say "==> Installing plugins"
  mkdir -p "$PLUGINS_DIR"

  install_plugin zsh-autosuggestions \
    https://github.com/zsh-users/zsh-autosuggestions

  install_plugin zsh-completions \
    https://github.com/zsh-users/zsh-completions

  install_plugin zsh-history-substring-search \
    https://github.com/zsh-users/zsh-history-substring-search

  install_plugin fast-syntax-highlighting \
    https://github.com/zdharma-continuum/fast-syntax-highlighting
}

# -------------- thefuck install --------------
install_thefuck() {
  say "==> Installing thefuck"

  if is_macos && have brew; then
    brew install thefuck || true
    return 0
  fi

  # Linux: prefer system package if available
  if have apt; then
    sudo apt install -y thefuck || true
  elif have dnf; then
    sudo dnf install -y thefuck || true
  elif have pacman; then
    sudo pacman -S --noconfirm thefuck || true
  fi

  # If still not found, install via pipx (best) or pip (fallback)
  if ! have thefuck; then
    if have pipx; then
      pipx install thefuck || pipx upgrade thefuck
    else
      # try to ensure pipx exists
      if have python3; then
        python3 -m pip install --user -U pip pipx >/dev/null 2>&1 || true
        if [ -x "$HOME/.local/bin/pipx" ]; then
          "$HOME/.local/bin/pipx" ensurepath >/dev/null 2>&1 || true
          "$HOME/.local/bin/pipx" install thefuck || "$HOME/.local/bin/pipx" upgrade thefuck
        else
          # fallback: pip --user (less ideal but works)
          python3 -m pip install --user -U thefuck
        fi
      else
        say "⚠️ python3 not found; cannot install thefuck via pip."
      fi
    fi
  fi

  if have thefuck; then
    say "  - thefuck installed: $(command -v thefuck)"
  else
    say "⚠️ thefuck could not be installed automatically."
  fi
}

# -------------- uv install (systemwide-ish) --------------
install_uv() {
  say "==> Installing uv"

  # Prefer package managers when present
  if is_macos && have brew; then
    brew install uv || true
  elif have apt; then
    # uv may not be in default repos; use official installer if not present
    :
  elif have dnf; then
    :
  elif have pacman; then
    :
  fi

  if have uv; then
    say "  - uv installed: $(command -v uv)"
    return 0
  fi

  # Official installer (installs to ~/.local/bin by default)
  curl -fsSL https://astral.sh/uv/install.sh | sh

  if have uv; then
    say "  - uv installed: $(command -v uv)"
  else
    say "⚠️ uv installed but may not be on PATH yet (usually ~/.local/bin)."
  fi
}

# -------------- .zshrc update --------------
update_zshrc() {
  say "==> Updating ~/.zshrc plugin list"
  ZSHRC="$HOME/.zshrc"

  # Ensure file exists
  [ -f "$ZSHRC" ] || touch "$ZSHRC"

  # Backup once
  [ -f "$ZSHRC.pre-ohmyzsh-backup" ] || cp "$ZSHRC" "$ZSHRC.pre-ohmyzsh-backup"

  # Remove any existing plugins=(...) block (handles multi-line blocks)
  # This deletes from a line starting with plugins=( up to the next ')'
  # Works on both GNU/BSD sed.
  if grep -q "^plugins=(" "$ZSHRC"; then
    # Use sed range delete
    sedi '/^plugins=(/,/^[[:space:]]*)[[:space:]]*$/d' "$ZSHRC"
  fi

  # Append clean plugins block (no blank lines)
  {
    echo ""
    echo "plugins=(${PLUGINS})"
  } >> "$ZSHRC"

  # Enable zsh-completions safely (no duplicates)
  if ! grep -q "plugins/zsh-completions/src" "$ZSHRC"; then
    cat >> "$ZSHRC" <<'EOF'

# zsh-completions
fpath+=${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-completions/src
autoload -Uz compinit && compinit
EOF
  fi

  # Add thefuck alias hook if installed (no duplicates)
  if have thefuck && ! grep -q "thefuck --alias" "$ZSHRC"; then
    cat >> "$ZSHRC" <<'EOF'

# thefuck
eval "$(thefuck --alias)"
EOF
  fi

  # Ensure ~/.local/bin is on PATH for uv/pipx installs (no duplicates)
  if ! grep -q 'HOME/.local/bin' "$ZSHRC"; then
    cat >> "$ZSHRC" <<'EOF'

# user local bin (uv/pipx)
export PATH="$HOME/.local/bin:$PATH"
EOF
  fi
}

# -------------- Default shell --------------
set_default_shell() {
  say "==> Setting Zsh as default shell"
  ZSH_BIN="$(command -v zsh || true)"
  if [ -n "$ZSH_BIN" ] && [ "${SHELL:-}" != "$ZSH_BIN" ]; then
    chsh -s "$ZSH_BIN" || say "⚠️ Could not change default shell automatically"
  fi
}

main() {
  say "==> Detecting OS: $(uname -s)"
  install_prereqs
  install_ohmyzsh
  install_plugins
  install_thefuck
  install_uv
  update_zshrc
  set_default_shell

  say "✅ Installation complete!"
  say "➡️ Restart your terminal or run: exec zsh"
}

main "$@"
