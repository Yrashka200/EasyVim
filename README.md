# EasyVim

EasyVim is a personal Neovim configuration written in Lua. It aims to make Neovim comfortable to use as a code editor right after installation, while keeping the configuration small and approachable enough to customize.

The setup is organized into Lua modules for editor options, keymaps, and plugin groups. A small plugin manager written for EasyVim handles Git-based installation and updates; it has no dependency on LazyVim or `lazy.nvim`. To change settings or key bindings, edit the relevant files under `lua/myconfig/`; to add or configure plugins, edit the files under `lua/myconfig/plugins/`.

