# EasyVim

EasyVim is a personal Neovim configuration written in Lua. It aims to make Neovim comfortable to use as a code editor right after installation, while keeping the configuration small and approachable enough to customize.

The setup is organized into separate Lua modules for editor options, keymaps, and plugin groups. Plugins are managed by `lazy.nvim`, which is bootstrapped automatically on the first launch. To change settings or key bindings, edit the relevant files under `lua/myconfig/`; to add or configure plugins, edit the files under `lua/myconfig/plugins/`.

## Features

- **Dashboard and navigation:** A startup dashboard, file explorer, buffer tabs, and Telescope pickers for files, recent files, open buffers, help, and text search.
- **Coding tools:** Treesitter syntax highlighting and indentation, LSP support, and completion for Lua, Python, and TypeScript/JavaScript.
- **Plugin-managed language servers:** Mason is configured for `lua_ls`, `pyright`, and `ts_ls`.
- **Git and terminal:** Git change markers in the sign column and a floating terminal inside Neovim.
- **Editing conveniences:** Automatic saving, automatic pairing of brackets and quotes, and Markdown preview in a browser.
- **Appearance:** A status line and several installed colorscheme options. The current configuration selects the Tokyo Night theme.
- **Optional AI assistance:** GitHub Copilot suggestions and Copilot Chat, available when configured with an eligible GitHub account.
- **Personal shortcuts:** A Spotify Web command and an optional AutoHotkey shortcut for Windows Terminal.

## Key bindings

The leader key is **Space**. Some useful defaults:

| Key | Action |
| --- | --- |
| `Space e` | Toggle the file explorer |
| `Space f f` | Find files |
| `Space f g` | Search text in files (requires `ripgrep`) |
| `Space f m` | Open the Files menu |
| `Space c m` | Open the Config menu |
| `Space w` | Save the current file |
| `Space q` | Quit |
| `Ctrl-h/j/k/l` | Move between windows |
| `Shift-h` / `Shift-l` | Previous / next buffer |
| `Ctrl-\` | Toggle the floating terminal |
| `gd` / `K` | Go to definition / show LSP hover information |
| `Space r n` / `Space c a` | Rename symbol / show code actions |

Additional shortcuts are defined alongside their related plugins in `lua/myconfig/plugins/`.

## Requirements

- Neovim 0.11 or later
- Git, for bootstrapping the plugin manager and installing plugins
- Internet access on the first launch
- A C compiler may be needed to build Treesitter parsers; `ripgrep` enables Telescope's live text search
- Node.js and npm are needed to build the Markdown preview plugin

Mason installs the configured Lua, Python, and TypeScript/JavaScript language servers from within Neovim. GitHub Copilot features are optional and require a GitHub account with Copilot access.

## Installation

1. Install Neovim and the requirements listed above.
2. Clone or download this project.
3. Run the installer from the project directory:
   - **Windows:** Open Git Bash in the project directory and run `bash install.sh`. (WSL uses the Linux instructions below.)
   - **macOS/Linux:** Run `bash install.sh`.
4. If a Neovim configuration already exists, the installer copies it to a timestamped backup before installing EasyVim. It does not remove existing files from the destination.
5. Start Neovim. The configuration automatically downloads `lazy.nvim`; the plugin manager will then install the configured plugins. Restart Neovim if prompted.
6. Open `:Mason` to manage language servers, or `:Lazy` to manage plugins.

The installer copies the configuration files; it does not install Neovim, Git, or other system requirements.

## Customization

- **Editor behavior:** Change options such as line numbers, indentation, and search behavior in `lua/myconfig/options.lua`.
- **General key bindings:** Edit `lua/myconfig/keymaps.lua`. Plugin-specific shortcuts are in their corresponding files under `lua/myconfig/plugins/`.
- **Plugins and language support:** Edit the plugin specifications under `lua/myconfig/plugins/`. After starting Neovim, use `:Lazy` to inspect or synchronize plugins and `:Mason` to manage language servers.
- **Colorscheme:** The active theme is selected in `lua/myconfig/plugins/ui.lua`; update its colorscheme command there to choose another installed theme.

## Optional Windows shortcut

`right-alt.ahk` is an optional AutoHotkey v2 script. When Windows Terminal is active, it maps Right Alt to F13. Run the script with AutoHotkey v2 only if you want this shortcut.
