return dofile(vim.fs.joinpath(
  vim.fn.stdpath("config"),
  "theme-changer-plugin",
  "lua",
  "theme_changer.lua"
))
