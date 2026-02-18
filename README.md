# Everything You Need

Installation link (script source):
`https://raw.githubusercontent.com/kst179/everything-you-need/refs/heads/main/install-zsh-and-plugins.sh`

## Install

Linux (apt/dnf/pacman + curl + run installer):
```bash
(command -v apt >/dev/null && sudo apt update && sudo apt install -y curl) || \
(command -v dnf >/dev/null && sudo dnf install -y curl) || \
(command -v pacman >/dev/null && sudo pacman -Sy --noconfirm curl)
curl -fsSL https://raw.githubusercontent.com/kst179/everything-you-need/refs/heads/main/install-zsh-and-plugins.sh | sh
```

macOS (Homebrew update + curl + run installer):
```bash
brew update && brew install curl
curl -fsSL https://raw.githubusercontent.com/kst179/everything-you-need/refs/heads/main/install-zsh-and-plugins.sh | sh
```

## Features

- Detects OS and installs prerequisites.
- Installs and configures Oh My Zsh.
- Installs selected Zsh plugins.
- Installs `uv` package/tool manager.
- Installs `thefuck` with `uv` (Python 3.11 by default).
- Installs Codex CLI via `npm`.
- Updates `~/.zshrc` with a managed block (plugins, completions, PATH, thefuck alias).
- Can restore broken/missing `~/.zshrc` with `--restore-zshrc`.
- Can preview actions with `--dry-run`.
- Sets Zsh as the default shell when possible.

## Installed Tools (Instruments)

- `git`: version control.
- `zsh`: shell used by Oh My Zsh.
- `curl`: downloader for remote installer scripts.
- `python3` + `pip`: Python runtime and package installer.
- `npm` / `node` (macOS via brew `node`): JavaScript package manager/runtime for Codex install.
- `uv`: fast Python tool/package manager.
- `thefuck`: command correction helper for shell history mistakes.
- `@openai/codex` (`codex` CLI): Codex command-line tool.
- Oh My Zsh: Zsh framework with plugin system and defaults.

## Installed Plugins

Enabled plugins:
- `git`: git aliases/completions.
- `thefuck`: shell integration for command correction.
- `sudo`: quick `ESC` `ESC` to prepend `sudo`.
- `zsh-autosuggestions`: command suggestions from history.
- `zsh-completions`: extra completion definitions.
- `zsh-history-substring-search`: history search by typed substring.
- `fast-syntax-highlighting`: command syntax highlighting.
- `virtualenv`: Python virtualenv helper aliases/functions.
