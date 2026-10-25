return {
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
}