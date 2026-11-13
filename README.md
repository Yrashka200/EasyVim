# EasyVim

EasyVim is a personal Neovim configuration written in Lua. It aims to make Neovim comfortable to use as a code editor right after installation, while keeping the configuration small and approachable enough to customize.

The setup is organized into Lua modules for editor options, keymaps, and plugin groups. A small plugin manager written for EasyVim handles Git-based installation and updates; it has no dependency on LazyVim or `lazy.nvim`. To change settings or key bindings, edit the relevant files under `lua/myconfig/`; to add or configure plugins, edit the files under `lua/myconfig/plugins/`.

## Features

- **Dashboard and navigation:** A startup dashboard, file explorer, buffer tabs, and Telescope pickers for files, recent files, open buffers, help, and text search.
- **Coding time:** An English dashboard side panel tracks active editor time by programming language, with daily and all-time totals. Open it at any time with `:CodingStats` or `<leader>cs`. Only focused Neovim time in recognized code buffers is counted; statistics are saved under Neovim's state directory.
- **Coding tools:** Treesitter syntax highlighting and indentation, LSP support, and completion for Lua, Python, TypeScript/JavaScript, and HTML. HTML also has Emmet support and LuaSnip templates: type `html5` for an HTML5 document or `.name` for `<div class="name"></div>`, then expand the completion.
- **Plugin-managed language servers:** Mason is configured for `lua_ls`, `pyright`, `ts_ls`, `html`, and `emmet_ls`.
- **Plugin manager:** Run `:PluginManager` or press `Space p i` for the single plugin menu. Install from a popular list or GitHub, manage installed plugins, read each plugin's README, edit its settings, update or remove it, and open built-in usage help. CLI commands include `:PluginManager sync`, `:PluginManager install owner/repo`, `:PluginManager update all`, `:PluginManager new owner/repo`, and `:PluginManager help`. New manager-owned plugins are installed under Neovim's data directory at `easyvim/plugins/`. Only install repositories you trust: plugin code runs inside Neovim. GitHub search requires `curl` and internet access and is subject to GitHub's unauthenticated API rate limit.
- **Per-plugin configuration:** Use **Manage my plugins → Configure / edit plugin settings** to edit one plugin at a time. Built-in plugin settings are kept in individual override files under `lua/myconfig/plugins/user/`, separate from grouped plugin lists; the user specs override the matching plugin's base spec. Specs support `opts`, `init`, `config`, `keys`, dependencies, branch selection, and build commands. For plugins with a custom built-in `config` function, replace that function in the override if you need to change its `setup()` call.
- **Plugin operation progress:** Installing or updating plugins opens a progress window with Git's transfer progress, elapsed time, and an estimated time remaining. Build commands appear as a separate step because Git cannot estimate their duration. Completion or errors are shown in a centered EasyVim popup; press `q`, Enter, or Esc to close it.
- **Migration:** Existing plugin checkouts in Neovim's old `nvim-data/lazy/` folder are reused; the new manager does not load or invoke `lazy.nvim`. New checkouts use `nvim-data/easyvim/plugins/`. The manager eagerly loads configured plugins at startup for a simpler setup model; after installing or updating plugins, restart Neovim to load their changes.
- **Git and terminal:** Git change markers in the sign column and a floating terminal inside Neovim.
- **Editing conveniences:** Automatic saving, automatic pairing of brackets and quotes, and Markdown preview in a browser.
- **Appearance:** A status line and the local `theme-changer.nvim` plugin, with a catalog of popular colorschemes. Run `:theme` to choose a theme; run `:PluginManager sync` and restart Neovim to install any missing catalog themes.
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
| `Space p i` | Open the plugin manager |
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
- Git, for installing and updating plugins
- `curl` and internet access for GitHub plugin search
- Internet access on the first launch
- A C compiler may be needed to build Treesitter parsers; `ripgrep` enables Telescope's live text search
- Node.js and npm are needed to build the Markdown preview plugin

Mason installs the configured Lua, Python, and TypeScript/JavaScript language servers from within Neovim. GitHub Copilot features are optional and require a GitHub account with Copilot access.

## Installation

1. Clone or download this project.
2. Run the installer from the project directory:
   - **Windows:** Open Git Bash in the project directory and run `bash install.sh`. (WSL uses the Linux instructions below.)
   - **macOS/Linux:** Run `bash install.sh`.
3. Before doing anything else, the installer checks the Neovim configuration directory and reports its path. If it already contains files, the installer leaves it completely unchanged and exits; it does not download or apply updates. If there is no existing configuration, it downloads the latest `main` branch from [YRashka200/EasyVim](https://github.com/Yrashka200/EasyVim) and installs it.
4. For a new installation, the installer checks for Neovim 0.11+, Git, curl, and Node.js/npm. If anything is missing, it offers to install the requirements using Winget/Chocolatey/Scoop on Windows, Homebrew on macOS, or apt/dnf/pacman/zypper on Linux. Use `bash install.sh --yes` to accept that offer automatically. Linux package installation may require `sudo`; package availability and Neovim versions depend on your distribution. `ripgrep` is optional; without it Telescope's live text search (`Space f g`) is unavailable, but installation continues.
5. Installation progress reports completed percentage, elapsed time, and an estimated remaining time. Package managers may also display their own download progress; the estimate is approximate because package installation time varies by network and system.
6. Start Neovim and run `:PluginManager sync` to install any missing configured plugins. Restart Neovim after installation.
7. Open `:Mason` to manage language servers, or `:PluginManager` to manage plugins.

The installer does not install a system package manager or compiler. A C compiler may be needed to build Treesitter parsers, and Node.js/npm are needed to build the Markdown preview plugin.

## Customization

- **Editor behavior:** Change options such as line numbers, indentation, and search behavior in `lua/myconfig/options.lua`.
- **General key bindings:** Edit `lua/myconfig/keymaps.lua`. Plugin-specific shortcuts are in their corresponding files under `lua/myconfig/plugins/`.
- **Plugins and language support:** Start from the dashboard's single **Plugins** button or run `:PluginManager`. Choose **Manage my plugins** to open instructions, configure, update, or remove a plugin. Choose **Help — how to use this menu** for an in-editor guide.
- **Plugins:** In `:PluginManager`, choose **Manage my plugins → Configure / edit plugin settings** to open that plugin's individual file under `lua/myconfig/plugins/user/`; built-in plugins get an override file without changing their grouped base spec. Edit `opts`, `init`, `config`, `keys`, or other supported fields, then restart Neovim. Use `:PluginManager new owner/repo` to scaffold a new standalone plugin spec. `opts` invokes the inferred module's `setup()` when the plugin has no custom `config`; set `main = "module-name"` when inference is not correct. Plugins are loaded eagerly at startup rather than on Lazy-specific events.
- **Community plugins:** Simple additions entered through the manager are saved in `lua/myconfig/plugins/community.lua`; the Configure action creates a dedicated per-plugin settings file. Existing community plugins are already stored individually under `lua/myconfig/plugins/user/`.
- **Colorscheme:** Run `:theme` to open the `theme-changer.nvim` catalog and switch themes. Add or remove catalog entries in `theme-changer-plugin/lua/theme_changer.lua`; configure their plugin sources in `lua/myconfig/plugins/ui.lua`.

## Optional Windows shortcut

`right-alt.ahk` is an optional AutoHotkey v2 script. When Windows Terminal is active, it maps Right Alt to F13. Run the script with AutoHotkey v2 only if you want this shortcut.
