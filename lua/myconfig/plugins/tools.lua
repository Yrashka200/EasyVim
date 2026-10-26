return {
  -- Значки изменений Git на полях
  {
    "lewis6991/gitsigns.nvim",
    config = function()
      require("gitsigns").setup()
    end,
  },
  -- Удобный терминал внутри Neovim
  {
    "akinsho/toggleterm.nvim",
    version = "*",
    config = function()
      require("toggleterm").setup({
        size = 20,
        open_mapping = [[<c-\>]], -- Родная комбинация Ctrl + \ (обратный слэш)
        direction = "float",      -- Открывать в плавающем окне по центру
        shade_terminals = true,
        float_opts = {
          border = "curved",
          winblend = 0,
        },
      })

      -- Дополнительные удобные бинды
      -- Ctrl + / (часто передается как Ctrl + _)
      vim.keymap.set("n", "<C-_>", ":ToggleTerm<CR>", { desc = "Открыть терминал" })
      
      -- В режиме терминала: Esc возвращает в нормальный режим, Ctrl+/ закрывает
      vim.keymap.set("t", "<Esc>", [[<C-\><C-n>]], { desc = "Выйти в нормальный режим" })
      vim.keymap.set("t", "<C-_>", [[<C-\><C-n>:ToggleTerm<CR>]], { desc = "Закрыть терминал" })

      require("myconfig.music").setup()
    end,
  },
  -- Автозакрытие скобок и кавычек
  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    config = function()
      require("nvim-autopairs").setup({})
    end,
  },
}