#!/usr/bin/env sh
set -eu

# ---------------- CONFIG ----------------
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
PLUGINS_DIR="$ZSH_CUSTOM/plugins"
ZSHRC_BACKUP="$HOME/.zshrc.pre-ohmyzsh-backup"
RESTORE_ZSHRC=0
DRY_RUN=0

# Keep as space-separated (easier to loop + avoids blank lines)
PLUGINS="git thefuck sudo zsh-autosuggestions zsh-completions zsh-history-substring-search fast-syntax-highlighting virtualenv"
# ----------------------------------------

say() { printf "%s\n" "$*"; }

have() { command -v "$1" >/dev/null 2>&1; }

is_macos() { [ "$(uname -s)" = "Darwin" ]; }

usage() {
  cat <<'EOF'
Usage: install-zsh-and-plugins.sh [OPTIONS]

Options:
  --restore-zshrc    Restore ~/.zshrc from backup/template if it is missing or broken
  --dry-run          Print planned actions without changing the system
  -h, --help         Show this help message
EOF
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --restore-zshrc) RESTORE_ZSHRC=1 ;;
      --dry-run) DRY_RUN=1 ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        say "Unknown option: $1"
        usage
        exit 1
        ;;
    esac
    shift
  done
}

is_dry_run() { [ "$DRY_RUN" -eq 1 ]; }

run_cmd() {
  if is_dry_run; then
    say "  [dry-run] $*"
    return 0
  fi
  "$@"
}

run_uv_installer() {
  if is_dry_run; then
    say "  [dry-run] curl -fsSL https://astral.sh/uv/install.sh | sh"
    return 0
  fi
  curl -fsSL https://astral.sh/uv/install.sh | sh
}

# portable in-place edit (GNU/BSD sed)
sedi() {
  # usage: sedi 's/foo/bar/' file
  if is_dry_run; then
    say "  [dry-run] sed -i '$1' '$2'"
    return 0
  fi

  if is_macos; then
    sed -i '' "$1" "$2"
  else
    sed -i "$1" "$2"
  fi
}

# -------------- Package install helpers --------------
install_pkgs_linux() {
  if have apt; then
    run_cmd sudo apt update
    run_cmd sudo apt install -y git zsh curl python3 python3-pip npm
  elif have dnf; then
    run_cmd sudo dnf install -y git zsh curl python3 python3-pip npm
  elif have pacman; then
    run_cmd sudo pacman -Sy --noconfirm git zsh curl python python-pip npm
  else
    say "⚠️ No supported Linux package manager detected. Assuming deps exist."
  fi
}

install_pkgs_macos() {
  if ! have brew; then
    say "⚠️ Homebrew not found. Install it first: https://brew.sh"
    say "   Continuing without brew; uv will use the official installer."
  else
    run_cmd brew install git zsh curl python node || true
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
    if is_dry_run; then
      say "  [dry-run] RUNZSH=no CHSH=no sh -c \"\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\""
    else
      RUNZSH=no CHSH=no sh -c \
        "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    fi
  else
    say "Oh My Zsh already installed"
  fi
}

# -------------- Plugins --------------
install_plugin() {
  name="$1"
  repo="$2"
  if [ ! -d "$PLUGINS_DIR/$name" ]; then
    run_cmd git clone --depth=1 "$repo" "$PLUGINS_DIR/$name"
  else
    say "  - $name already installed"
  fi
}

install_plugins() {
  say "==> Installing plugins"
  run_cmd mkdir -p "$PLUGINS_DIR"

  install_plugin zsh-autosuggestions \
    https://github.com/zsh-users/zsh-autosuggestions

  install_plugin zsh-completions \
    https://github.com/zsh-users/zsh-completions

  install_plugin zsh-history-substring-search \
    https://github.com/zsh-users/zsh-history-substring-search

  install_plugin fast-syntax-highlighting \
    https://github.com/zdharma-continuum/fast-syntax-highlighting
}

# -------------- uv install (systemwide-ish) --------------
resolve_uv_bin() {
  if have uv; then
    command -v uv
    return 0
  fi

  if [ -x "$HOME/.local/bin/uv" ]; then
    printf "%s\n" "$HOME/.local/bin/uv"
    return 0
  fi

  return 1
}

install_uv() {
  say "==> Installing uv"

  # Prefer package managers when present
  if is_macos && have brew; then
    run_cmd brew install uv || true
  elif have apt; then
    # uv may not be in default repos; use official installer if not present
    :
  elif have dnf; then
    :
  elif have pacman; then
    :
  fi

  UV_BIN="$(resolve_uv_bin || true)"
  if [ -n "$UV_BIN" ]; then
    say "  - uv installed: $UV_BIN"
    return 0
  fi

  # Official installer (installs to ~/.local/bin by default)
  run_uv_installer

  if is_dry_run; then
    say "  - dry-run: skipped post-install uv path checks"
    return 0
  fi

  UV_BIN="$(resolve_uv_bin || true)"
  if [ -n "$UV_BIN" ]; then
    say "  - uv installed: $UV_BIN"
  else
    say "⚠️ uv installed but may not be on PATH yet (usually ~/.local/bin)."
  fi
}

# -------------- thefuck install (via uv + Python 3.11) --------------
install_thefuck() {
  THEFUCK_PYTHON="${THEFUCK_PYTHON:-3.11}"
  say "==> Installing thefuck with uv (Python $THEFUCK_PYTHON)"

  UV_BIN="$(resolve_uv_bin || true)"
  if [ -z "$UV_BIN" ]; then
    if is_dry_run; then
      UV_BIN="$HOME/.local/bin/uv"
      say "  - dry-run: uv not found in current PATH; assuming $UV_BIN after installation"
    else
      say "⚠️ uv not found; skipping thefuck install."
      return 0
    fi
  fi

  if ! run_cmd "$UV_BIN" tool install --python "$THEFUCK_PYTHON" --force thefuck; then
    say "⚠️ thefuck could not be installed with uv using Python $THEFUCK_PYTHON."
    return 0
  fi

  if is_dry_run; then
    say "  - dry-run: skipped post-install thefuck path checks"
    return 0
  fi

  if have thefuck; then
    say "  - thefuck installed: $(command -v thefuck)"
  elif [ -x "$HOME/.local/bin/thefuck" ]; then
    say "  - thefuck installed: $HOME/.local/bin/thefuck"
  else
    say "⚠️ thefuck installed but may not be on PATH yet (usually ~/.local/bin)."
  fi
}

# -------------- Codex CLI install (via npm) --------------
install_codex() {
  say "==> Installing Codex CLI with npm"

  if ! have npm; then
    say "⚠️ npm not found; skipping Codex CLI install."
    return 0
  fi

  if ! run_cmd npm install -g @openai/codex; then
    say "⚠️ Codex CLI installation failed."
    return 0
  fi

  if is_dry_run; then
    say "  - dry-run: skipped post-install codex path checks"
    return 0
  fi

  if have codex; then
    say "  - codex installed: $(command -v codex)"
  else
    say "⚠️ Codex CLI installed but may not be on PATH yet."
  fi
}

# -------------- .zshrc restore/update --------------
is_zshrc_broken_or_missing() {
  file="$1"
  [ ! -f "$file" ] && return 0
  [ ! -s "$file" ] && return 0
  grep -q "oh-my-zsh.sh" "$file" || return 0
  return 1
}

restore_zshrc_if_requested() {
  [ "$RESTORE_ZSHRC" -eq 1 ] || return 0

  ZSHRC="$HOME/.zshrc"
  TEMPLATE="$HOME/.oh-my-zsh/templates/zshrc.zsh-template"

  if is_zshrc_broken_or_missing "$ZSHRC"; then
    say "==> Restoring ~/.zshrc (--restore-zshrc enabled)"
    if [ -f "$ZSHRC_BACKUP" ] && [ -s "$ZSHRC_BACKUP" ]; then
      run_cmd cp "$ZSHRC_BACKUP" "$ZSHRC"
      say "  - restored from $ZSHRC_BACKUP"
    elif [ -f "$TEMPLATE" ]; then
      run_cmd cp "$TEMPLATE" "$ZSHRC"
      say "  - restored from $TEMPLATE"
    else
      run_cmd touch "$ZSHRC"
      say "  - no backup/template found; created empty ~/.zshrc"
    fi
  else
    say "==> ~/.zshrc looks healthy; restore skipped"
  fi
}

write_managed_zsh_block() {
  cat <<EOF
# >>> codex-zsh-managed >>>
# Managed by install-zsh-and-plugins.sh. Do not edit inside this block.
plugins=($PLUGINS)

# Adds a directory to PATH only once.
add_to_path() {
  [ -n "\$1" ] || return 0
  case ":\$PATH:" in
    *":\$1:"*) ;;
    *) export PATH="\$1:\$PATH" ;;
  esac
}

add_to_path "\$HOME/.local/bin"

# zsh-completions
fpath+=\${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-completions/src
autoload -Uz compinit && compinit

# thefuck
if command -v thefuck >/dev/null 2>&1; then
  eval "\$(thefuck --alias)"
fi
# <<< codex-zsh-managed <<<
EOF
}

insert_managed_block() {
  zshrc="$1"

  if is_dry_run; then
    say "  [dry-run] insert managed zsh block into $zshrc"
    return 0
  fi

  tmp_file="$(mktemp)"
  block="$(write_managed_zsh_block)"

  awk -v block="$block" '
    BEGIN { inserted = 0 }
    /^[[:space:]]*source[[:space:]].*oh-my-zsh\.sh/ && inserted == 0 {
      print block
      print ""
      inserted = 1
    }
    { print }
    END {
      if (inserted == 0) {
        if (NR > 0) {
          print ""
        }
        print block
      }
    }
  ' "$zshrc" > "$tmp_file"

  mv "$tmp_file" "$zshrc"
}

cleanup_legacy_zshrc_entries() {
  zshrc="$1"
  [ -f "$zshrc" ] || return 0

  if grep -q "^# zsh-completions$" "$zshrc"; then
    sedi '/^# zsh-completions$/,/^autoload -Uz compinit && compinit$/d' "$zshrc"
  fi

  if grep -q "^# thefuck$" "$zshrc"; then
    sedi '/^# thefuck$/,/^eval "\$(thefuck --alias)"$/d' "$zshrc"
  fi

  if grep -q "^# user local bin (uv\/pipx)$" "$zshrc"; then
    sedi '/^# user local bin (uv\/pipx)$/,/^export PATH="\$HOME\/\.local\/bin:\$PATH"$/d' "$zshrc"
  fi
}

update_zshrc() {
  say "==> Updating ~/.zshrc"
  ZSHRC="$HOME/.zshrc"
  TEMPLATE="$HOME/.oh-my-zsh/templates/zshrc.zsh-template"

  # Ensure file exists, prefer Oh My Zsh template when available
  if [ ! -f "$ZSHRC" ]; then
    if [ -f "$TEMPLATE" ]; then
      run_cmd cp "$TEMPLATE" "$ZSHRC"
    else
      run_cmd touch "$ZSHRC"
    fi
  fi

  # Backup once
  [ -f "$ZSHRC_BACKUP" ] || run_cmd cp "$ZSHRC" "$ZSHRC_BACKUP"

  cleanup_legacy_zshrc_entries "$ZSHRC"

  # Remove previously managed block, then insert fresh block once.
  if [ -f "$ZSHRC" ] && grep -q "^# >>> codex-zsh-managed >>>$" "$ZSHRC"; then
    sedi '/^# >>> codex-zsh-managed >>>$/,/^# <<< codex-zsh-managed <<<$/d' "$ZSHRC"
  fi

  insert_managed_block "$ZSHRC"
}

# -------------- Default shell --------------
set_default_shell() {
  say "==> Setting Zsh as default shell"
  ZSH_BIN="$(command -v zsh || true)"
  if [ -n "$ZSH_BIN" ] && [ "${SHELL:-}" != "$ZSH_BIN" ]; then
    run_cmd chsh -s "$ZSH_BIN" || say "⚠️ Could not change default shell automatically"
  fi
}

main() {
  parse_args "$@"

  if is_dry_run; then
    say "==> Dry-run mode enabled (no changes will be made)"
  fi

  say "==> Detecting OS: $(uname -s)"
  install_prereqs
  install_ohmyzsh
  restore_zshrc_if_requested
  install_plugins
  install_uv
  install_thefuck
  install_codex
  update_zshrc
  set_default_shell

  say "✅ Installation complete!"
  say "➡️ Restart your terminal or run: exec zsh"
}

main "$@"
