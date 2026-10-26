return {
  -- Автосохранение изменённых файлов
  {
    "okuuva/auto-save.nvim",
    event = { "BufReadPost", "BufNewFile" },
    opts = {
      debounce_delay = 1000,
      condition = function(buf)
        local excluded_filetypes = {
          "gitcommit",
          "neo-tree",
          "TelescopePrompt",
          "toggleterm",
        }

        return vim.bo[buf].buftype == "" and not vim.tbl_contains(excluded_filetypes, vim.bo[buf].filetype)
      end,
    },
  },

  -- GitHub Copilot: ИИ-подсказки кода
  {
    "github/copilot.vim",
    init = function()
      vim.g.copilot_no_tab_map = true
    end,
    config = function()
      vim.keymap.set("i", "<C-J>", function()
        return vim.fn["copilot#Accept"]("\r")
      end, { expr = true, replace_keycodes = false, desc = "Accept Copilot suggestion" })
      vim.keymap.set("n", "<leader>ap", "<cmd>Copilot panel<cr>", { desc = "Open Copilot panel" })
    end,
  },
  {
    "CopilotC-Nvim/CopilotChat.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    opts = {},
    cmd = {
      "CopilotChat",
      "CopilotChatOpen",
      "CopilotChatClose",
      "CopilotChatToggle",
      "CopilotChatStop",
      "CopilotChatReset",
      "CopilotChatSave",
      "CopilotChatLoad",
      "CopilotChatPrompts",
      "CopilotChatModels",
    },
    keys = {
      { "<leader>ac", "<cmd>CopilotChatToggle<cr>", desc = "Toggle Copilot Chat" },
    },
  },

  -- Дерево файлов
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    dependencies = { "nvim-lua/plenary.nvim", "nvim-tree/nvim-web-devicons", "MunifTanjim/nui.nvim" },
    config = function()
      vim.keymap.set("n", "<leader>e", ":Neotree toggle<CR>", { desc = "Explorer" })
      require("neo-tree").setup({ close_if_last_window = true })
    end,
  },

  -- Поиск (Telescope)
  {
    "nvim-telescope/telescope.nvim",
    branch = "0.1.x",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      -- ФИКС: Отключаем багованную подсветку Treesitter в предпросмотре
      require("telescope").setup({
        defaults = {
          preview = {
            treesitter = false,
          },
        },
      })

      local builtin = require("telescope.builtin")
      local pickers = require("telescope.pickers")
      local finders = require("telescope.finders")
      local conf = require("telescope.config").values
      local actions = require("telescope.actions")
      local action_state = require("telescope.actions.state")

      -- Основные горячие клавиши
      vim.keymap.set("n", "<leader>ff", builtin.find_files, { desc = "Find File" })
      vim.keymap.set("n", "<leader>fg", builtin.live_grep, { desc = "Find Text" })
      vim.keymap.set("n", "<leader>fb", builtin.buffers, { desc = "Buffers" })
      vim.keymap.set("n", "<leader>fh", builtin.help_tags, { desc = "Help" })

      -- Функция для создания "шторок" (ИСПРАВЛЕНО: title вместо prompt_title)
      local function custom_menu(title, items)
        local opts = { title = " " .. title .. " " }
        pickers.new(opts, {
          finder = finders.new_table({
            results = items,
            entry_maker = function(entry)
              return {
                value = entry,
                display = entry.name,
                ordinal = entry.name,
              }
            end,
          }),
          sorter = conf.generic_sorter(opts),
          attach_mappings = function(prompt_bufnr, map)
            actions.select_default:replace(function()
              actions.close(prompt_bufnr)
              local selection = action_state.get_selected_entry()
              vim.cmd(selection.value.cmd)
            end)
            return true
          end,
        }):find()
      end

      -- ШТОРКА: Files
      vim.keymap.set("n", "<leader>fm", function()
        custom_menu("Files Menu", {
          { name = "  Find File", cmd = "Telescope find_files" },
          { name = "  Recent Files", cmd = "Telescope oldfiles" },
          { name = "  New File", cmd = "ene | startinsert" },
          { name = "  Explorer Tree", cmd = "Neotree toggle" },
          { name = "  Find Text", cmd = "Telescope live_grep" },
        })
      end, { desc = "Files Menu" })

      -- ШТОРКА: Config
      vim.keymap.set("n", "<leader>cm", function()
        local config_path = vim.fn.stdpath("config")
        custom_menu("Config Menu", {
          { name = "  Edit Config Files", cmd = "Telescope find_files cwd=" .. config_path },
          { name = "  Plugin Manager", cmd = "Lazy" },
        })
      end, { desc = "Config Menu" })
    end,
  },

  -- Подсветка синтаксиса (Treesitter)
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    config = function()
      -- Установка парсеров (новый API)
      require("nvim-treesitter").setup({
        ensure_installed = { "lua", "vim", "vimdoc", "query", "python", "javascript", "typescript", "html", "css", "json" },
        auto_install = true,
      })

      -- Включение подсветки и отступов
      vim.api.nvim_create_autocmd("FileType", {
        callback = function()
          pcall(vim.treesitter.start)
          vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end,
      })
    end,
  },

  -- Предпросмотр Markdown в браузере
  {
    "iamcco/markdown-preview.nvim",
    cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
    ft = "markdown",
    build = "cd app && npm install",
    init = function()
      vim.g.mkdp_filetypes = { "markdown" }
      vim.g.mkdp_auto_start = 0
      vim.g.mkdp_auto_close = 1

      vim.api.nvim_create_autocmd("FileType", {
        pattern = "markdown",
        callback = function(event)
          vim.keymap.set("n", "f", "<cmd>MarkdownPreviewToggle<CR>", {
            buffer = event.buf,
            desc = "Toggle Markdown browser preview",
          })
        end,
      })
    end,
  },
} 