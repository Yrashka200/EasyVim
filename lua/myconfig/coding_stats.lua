local M = {}

local languages = {
  bash = "Bash",
  c = "C",
  cs = "C#",
  cpp = "C++",
  c_sharp = "C#",
  css = "CSS",
  dart = "Dart",
  elixir = "Elixir",
  go = "Go",
  html = "HTML",
  java = "Java",
  javascript = "JavaScript",
  javascriptreact = "JavaScript",
  json = "JSON",
  kotlin = "Kotlin",
  lua = "Lua",
  php = "PHP",
  python = "Python",
  r = "R",
  ruby = "Ruby",
  rust = "Rust",
  scala = "Scala",
  sh = "Shell",
  solidity = "Solidity",
  sql = "SQL",
  swift = "Swift",
  typescript = "TypeScript",
  typescriptreact = "TypeScript",
  vue = "Vue",
  yaml = "YAML",
  zig = "Zig",
}

local state_path = vim.fs.joinpath(vim.fn.stdpath("state"), "coding-time.json")
local data = {
  date = os.date("%Y-%m-%d"),
  today = {},
  all_time = {},
}
local current_language
local started_at
local focused = true
local panel_buffer
local panel_window
local dashboard_buffer
local opened_for_dashboard = false
local timer

local function notify_error(message)
  vim.notify("Coding time: " .. message, vim.log.levels.ERROR)
end

local function counts_are_valid(counts)
  if type(counts) ~= "table" then
    return false
  end

  for language, seconds in pairs(counts) do
    if type(language) ~= "string" or type(seconds) ~= "number"
      or seconds < 0 or seconds ~= seconds or seconds == math.huge
    then
      return false
    end
  end

  return true
end

local function load_data()
  if vim.fn.filereadable(state_path) == 0 then
    return
  end

  local lines = vim.fn.readfile(state_path)
  local ok, saved = pcall(vim.json.decode, table.concat(lines, "\n"))
  if not ok or type(saved) ~= "table"
    or type(saved.date) ~= "string"
    or not counts_are_valid(saved.today)
    or not counts_are_valid(saved.all_time)
  then
    notify_error("saved statistics are invalid; starting with empty statistics")
    return
  end

  data = {
    date = saved.date,
    today = saved.today,
    all_time = saved.all_time,
  }

  if data.date ~= os.date("%Y-%m-%d") then
    data.date = os.date("%Y-%m-%d")
    data.today = {}
  end
end

local function save_data()
  local parent = vim.fs.dirname(state_path)
  vim.fn.mkdir(parent, "p")

  local result = vim.fn.writefile({ vim.json.encode(data) }, state_path)
  if result ~= 0 then
    notify_error("could not save statistics to " .. state_path)
  end
end

local function reset_today_if_needed()
  local today = os.date("%Y-%m-%d")
  if data.date ~= today then
    data.date = today
    data.today = {}
  end
end

local function format_time(seconds)
  if seconds < 60 then
    return string.format("%ds", math.floor(seconds))
  end

  local minutes = math.floor(seconds / 60)
  local hours = math.floor(minutes / 60)
  minutes = minutes % 60

  if hours > 0 then
    return string.format("%dh %02dm", hours, minutes)
  end

  return string.format("%dm", minutes)
end

local function ranked_languages(counts)
  local ranked = {}
  for language, seconds in pairs(counts) do
    if seconds > 0 then
      ranked[#ranked + 1] = { language = language, seconds = seconds }
    end
  end

  table.sort(ranked, function(a, b)
    if a.seconds == b.seconds then
      return a.language < b.language
    end
    return a.seconds > b.seconds
  end)

  return ranked
end

local function section_lines(title, counts)
  local lines = { title }
  local ranked = ranked_languages(counts)

  if #ranked == 0 then
    lines[#lines + 1] = "  No tracked time yet"
    return lines
  end

  for index = 1, math.min(#ranked, 5) do
    local entry = ranked[index]
    lines[#lines + 1] = string.format("  %-14s %8s", entry.language, format_time(entry.seconds))
  end

  if #ranked > 5 then
    lines[#lines + 1] = string.format("  +%d more", #ranked - 5)
  end

  return lines
end

local function panel_lines()
  reset_today_if_needed()

  local today = vim.tbl_extend("force", {}, data.today)
  local all_time = vim.tbl_extend("force", {}, data.all_time)
  if current_language and started_at and focused then
    local elapsed = (vim.uv.hrtime() - started_at) / 1e9
    today[current_language] = (today[current_language] or 0) + elapsed
    all_time[current_language] = (all_time[current_language] or 0) + elapsed
  end

  local lines = {
    "CODING TIME",
    "Active editor time",
    "",
  }
  vim.list_extend(lines, section_lines("TODAY", today))
  lines[#lines + 1] = ""
  vim.list_extend(lines, section_lines("ALL TIME", all_time))
  lines[#lines + 1] = ""
  lines[#lines + 1] = "Focused code buffers only"

  return lines
end

local function panel_config(lines)
  local width = math.min(34, vim.o.columns - 4)
  local height = math.min(#lines, vim.o.lines - 5)

  return {
    relative = "editor",
    row = math.max(1, math.floor((vim.o.lines - height - 2) / 2)),
    col = math.max(1, vim.o.columns - width - 2),
    width = width,
    height = height,
    style = "minimal",
    border = "rounded",
    focusable = false,
    zindex = 50,
  }
end

local function render_panel()
  if not panel_buffer or not vim.api.nvim_buf_is_valid(panel_buffer) then
    return
  end

  local lines = panel_lines()
  vim.bo[panel_buffer].modifiable = true
  vim.api.nvim_buf_set_lines(panel_buffer, 0, -1, false, lines)
  vim.bo[panel_buffer].modifiable = false

  if panel_window and vim.api.nvim_win_is_valid(panel_window) then
    vim.api.nvim_win_set_config(panel_window, panel_config(lines))
  end
end

local function close_panel()
  if panel_window and vim.api.nvim_win_is_valid(panel_window) then
    vim.api.nvim_win_close(panel_window, true)
  end
  panel_window = nil
  panel_buffer = nil
end

local function open_panel(from_dashboard)
  if vim.o.columns < 48 or vim.o.lines < 12 then
    vim.notify("Coding time panel needs a larger Neovim window", vim.log.levels.WARN)
    return
  end

  if panel_window and vim.api.nvim_win_is_valid(panel_window) then
    opened_for_dashboard = from_dashboard or false
    render_panel()
    return
  end

  panel_buffer = vim.api.nvim_create_buf(false, true)
  vim.bo[panel_buffer].buftype = "nofile"
  vim.bo[panel_buffer].bufhidden = "wipe"
  vim.bo[panel_buffer].swapfile = false
  vim.bo[panel_buffer].filetype = "codingstats"

  local lines = panel_lines()
  panel_window = vim.api.nvim_open_win(panel_buffer, false, panel_config(lines))
  opened_for_dashboard = from_dashboard or false
  render_panel()
end

local function flush_time()
  if not current_language or not started_at then
    return
  end

  local now = vim.uv.hrtime()
  local elapsed = (now - started_at) / 1e9
  if elapsed < 1 then
    return
  end

  reset_today_if_needed()
  data.today[current_language] = (data.today[current_language] or 0) + elapsed
  data.all_time[current_language] = (data.all_time[current_language] or 0) + elapsed
  started_at = now
  save_data()
  render_panel()
end

local function language_for_buffer(buffer)
  if vim.bo[buffer].buftype ~= "" then
    return nil
  end
  return languages[vim.bo[buffer].filetype]
end

local function sync_buffer()
  local language = language_for_buffer(vim.api.nvim_get_current_buf())
  if language == current_language then
    if language and focused and not started_at then
      started_at = vim.uv.hrtime()
    end
    return
  end

  flush_time()
  current_language = language
  started_at = focused and language and vim.uv.hrtime() or nil
  render_panel()
end

function M.toggle()
  if panel_window and vim.api.nvim_win_is_valid(panel_window) then
    close_panel()
    opened_for_dashboard = false
  else
    open_panel(vim.bo.filetype == "alpha")
  end
end

function M.setup()
  load_data()

  local group = vim.api.nvim_create_augroup("CodingTimeStats", { clear = true })
  vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
    group = group,
    callback = function()
      vim.schedule(sync_buffer)
    end,
  })
  vim.api.nvim_create_autocmd("FocusLost", {
    group = group,
    callback = function()
      flush_time()
      focused = false
      started_at = nil
      render_panel()
    end,
  })
  vim.api.nvim_create_autocmd("FocusGained", {
    group = group,
    callback = function()
      focused = true
      sync_buffer()
    end,
  })
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = "alpha",
    callback = function(event)
      dashboard_buffer = event.buf
      vim.schedule(function()
        if vim.api.nvim_buf_is_valid(event.buf) and vim.api.nvim_get_current_buf() == event.buf then
          open_panel(true)
        end
      end)
    end,
  })
  vim.api.nvim_create_autocmd("BufLeave", {
    group = group,
    callback = function(event)
      if event.buf == dashboard_buffer and opened_for_dashboard then
        close_panel()
        opened_for_dashboard = false
        dashboard_buffer = nil
      end
    end,
  })
  vim.api.nvim_create_autocmd("VimResized", {
    group = group,
    callback = render_panel,
  })
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = function()
      flush_time()
      if timer then
        timer:stop()
        timer:close()
      end
    end,
  })

  timer = vim.uv.new_timer()
  timer:start(60000, 60000, vim.schedule_wrap(flush_time))

  vim.api.nvim_create_user_command("CodingStats", M.toggle, {
    desc = "Toggle coding time statistics",
  })
  vim.keymap.set("n", "<leader>cs", M.toggle, { desc = "Toggle coding time statistics" })
  sync_buffer()
end

return M
