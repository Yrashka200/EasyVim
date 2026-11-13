return {
  {
    "aikhe/wrapped.nvim",
    dependencies = { "nvzone/volt" },
    config = function()
      require("wrapped").setup({
        path = vim.fn.stdpath("config"),
      })
    end,
  },
}
