local M = {}

function M.setup()
  local function open_spotify_web()
    vim.ui.open("https://open.spotify.com/")
  end

  vim.api.nvim_create_user_command("SpotifyWeb", open_spotify_web, {
    desc = "Открыть Spotify Web в браузере",
  })
  vim.keymap.set("n", "<leader>mp", open_spotify_web, {
    desc = "Открыть Spotify Web",
  })
end

return M
