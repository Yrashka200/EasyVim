return {
  -- Popular colorschemes
  {
    "folke/tokyonight.nvim",
    opts = { style = "night" },
    config = function(_, opts)
      require("tokyonight").setup(opts)
      vim.cmd.colorscheme("tokyonight-night")
    end,
  },
  {
    "catppuccin/nvim",
    name = "catppuccin",
  },
  {
    "projekt0n/github-nvim-theme",
    name = "github-theme",
  },
  {
    "Mofiqul/vscode.nvim",
  },
  {
    "navarasu/onedark.nvim",
  },
  {
    "rebelot/kanagawa.nvim",
  },
  { "ellisonleao/gruvbox.nvim" },
  { "shaunsingh/nord.nvim" },
  { "sainnhe/everforest" },
  { "rose-pine/neovim", name = "rose-pine" },
  { "Mofiqul/dracula.nvim" },
  { "EdenEast/nightfox.nvim" },

  { "nvim-tree/nvim-web-devicons" },

  -- Startup dashboard
  {
    "goolord/alpha-nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      local alpha = require("alpha")
      local dashboard = require("alpha.themes.dashboard")
      require("myconfig.coding_stats").setup()

      dashboard.section.header.val = {
        "    ███████╗ █████╗ ███████╗██╗   ██╗██╗   ██╗██╗███╗   ███╗",
        "    ██╔════╝██╔══██╗██╔════╝╚██╗ ██╔╝██║   ██║██║████╗ ████║",
        "    █████╗  ███████║███████╗ ╚████╔╝ ██║   ██║██║██╔████╔██║",
        "    ██╔══╝  ██╔══██║╚════██║  ╚██╔╝  ╚██╗ ██╔╝██║██║╚██╔╝██║",
        "    ███████╗██║  ██║███████║   ██║    ╚████╔╝ ██║██║ ╚═╝ ██║",
        "    ╚══════╝╚═╝  ╚═╝╚══════╝   ╚═╝     ╚═══╝  ╚═╝╚═╝     ╚═╝",
        "                 [ Your personal code editor ]",
      }

      local function btn(shortcut, text, action)
        return dashboard.button(shortcut, "  " .. text, action)
      end

      -- Main menu buttons
      dashboard.section.buttons.val = {
        btn("f", "Files               (Open Menu)", "<leader>fm"),
        btn("c", "Config              (Open Menu)", "<leader>cm"),
        btn("p", "Plugins             (Install / manage / help)", ":PluginManager<CR>"),
        btn("q", "Quit Neovim         (App)", ":qa<CR>"),
      }

      dashboard.section.footer.val = function()
        local stats = require("myconfig.plugin_manager").stats()
        local ms = math.floor(stats.startuptime + 0.5)
        return " EasyVim | " .. stats.installed .. "/" .. stats.total .. " plugins | " .. ms .. "ms"
      end

      dashboard.opts.layout = {
        { type = "padding", val = 2 },
        dashboard.section.header,
        { type = "padding", val = 1 },
        dashboard.section.buttons,
        { type = "padding", val = 1 },
        dashboard.section.footer,
      }

      alpha.setup(dashboard.opts)
      vim.cmd([[autocmd FileType alpha setlocal nofoldenable]])
    end,
  },

  -- Status line
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("lualine").setup({ 
        options = { 
          theme = "auto",
          section_separators = { left = '', right = '' },
          component_separators = { left = '', right = '' },
        } 
      })
    end,
  },

  -- Buffer tabs
  {
    "akinsho/bufferline.nvim",
    dependencies = "nvim-tree/nvim-web-devicons",
    config = function()
      require("bufferline").setup({
        options = { 
          mode = "buffers", 
          separator_style = "slant",
          offsets = {
            { filetype = "neo-tree", text = "Explorer", highlight = "Directory", text_align = "left" }
          }
        },
      })
      vim.keymap.set("n", "<leader>bp", ":BufferLineTogglePin<CR>", { desc = "Pin tab" })
    end,
  },
}