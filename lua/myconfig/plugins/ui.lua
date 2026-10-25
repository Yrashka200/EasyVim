return {
  -- Коллекция популярных тем
  {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
    opts = { style = "night" },
  },
  {
    "catppuccin/nvim",
    name = "catppuccin",
    lazy = false,
    priority = 999,
  },
  {
    "projekt0n/github-nvim-theme",
    name = "github-theme",
    lazy = false,
    priority = 998,
  },
  {
    "Mofiqul/vscode.nvim",
    lazy = false,
    priority = 997,
  },
  {
    "navarasu/onedark.nvim",
    lazy = false,
    priority = 996,
  },
  {
    "rebelot/kanagawa.nvim",
    lazy = false,
    priority = 995,
    config = function()
      vim.cmd([[colorscheme tokyonight-night]])
    end,
  },
  
  { "nvim-tree/nvim-web-devicons", lazy = true },

  -- СТАРТОВОЕ МЕНЮ (Как на твоем втором фото)
  {
    "goolord/alpha-nvim",
    event = "VimEnter",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      local alpha = require("alpha")
      local dashboard = require("alpha.themes.dashboard")

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

      -- ГЛАВНОЕ МЕНЮ (4 кнопки)
      dashboard.section.buttons.val = {
        btn("f", "Files               (Open Menu)", "<leader>fm"),
        btn("c", "Config              (Open Menu)", "<leader>cm"),
        btn("l", "Plugin Manager      (App)", ":Lazy<CR>"),
        btn("q", "Quit Neovim         (App)", ":qa<CR>"),
      }

      dashboard.section.footer.val = function()
        local stats = require("lazy").stats()
        local ms = (math.floor(stats.startuptime * 100 + 0.5) / 100)
        return " EasyVim | Loaded " .. stats.loaded .. " plugins in " .. ms .. "ms"
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

  -- Статус-лайн
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

  -- Вкладки сверху
  {
    "akinsho/bufferline.nvim",
    version = "*",
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