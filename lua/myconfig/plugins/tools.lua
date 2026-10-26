return {
  -- Git change indicators in the sign column
  {
    "lewis6991/gitsigns.nvim",
    config = function()
      require("gitsigns").setup()
    end,
  },
  -- Floating terminal inside Neovim
  {
    "akinsho/toggleterm.nvim",
    version = "*",
    config = function()
      require("toggleterm").setup({
        size = 20,
        open_mapping = [[<c-\>]], -- Ctrl + \
        direction = "float",      -- Open in a centered floating window
        shade_terminals = true,
        float_opts = {
          border = "curved",
          winblend = 0,
        },
      })

      -- Additional keymaps
      -- Ctrl + / is often represented as Ctrl + _
      vim.keymap.set("n", "<C-_>", ":ToggleTerm<CR>", { desc = "Open terminal" })
      
      -- In terminal mode, Esc returns to normal mode and Ctrl + / closes the terminal
      vim.keymap.set("t", "<Esc>", [[<C-\><C-n>]], { desc = "Return to normal mode" })
      vim.keymap.set("t", "<C-_>", [[<C-\><C-n>:ToggleTerm<CR>]], { desc = "Close terminal" })

      require("myconfig.music").setup()
    end,
  },
  -- Automatically pair brackets and quotes
  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    config = function()
      require("nvim-autopairs").setup({})
    end,
  },
}