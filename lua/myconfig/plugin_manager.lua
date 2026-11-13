local M = {
  plugins = {},
  started_at = 0,
}

local progress

local catalog = {
  {
    name = "Editing",
    plugins = {
      { repo = "folke/which-key.nvim", description = "Discover available key bindings" },
      { repo = "folke/flash.nvim", description = "Fast motion and search" },
      { repo = "echasnovski/mini.nvim", description = "A collection of small, focused modules" },
      { repo = "stevearc/conform.nvim", description = "Formatting with external tools" },
      { repo = "mfussenegger/nvim-lint", description = "Asynchronous linting" },
      { repo = "kylechui/nvim-surround", description = "Manage surrounding characters" },
    },
  },
  {
    name = "Navigation and UI",
    plugins = {
      { repo = "stevearc/oil.nvim", description = "Edit directories like a buffer" },
      { repo = "folke/trouble.nvim", description = "Diagnostics and quickfix lists" },
      { repo = "folke/noice.nvim", description = "Messages and command-line UI" },
      { repo = "rcarriga/nvim-notify", description = "Notification UI" },
    },
  },
  {
    name = "Coding",
    plugins = {
      { repo = "folke/lazydev.nvim", description = "Lua development for Neovim configs" },
      { repo = "Saghen/blink.cmp", description = "Completion engine" },
    },
  },
}

local function notify(message, level)
  vim.notify(message, level or vim.log.levels.INFO, { title = "EasyVim Plugin Manager" })
end

local function valid_component(value)
  return value
    and value ~= "."
    and value ~= ".."
    and value:match("^[%w_.-]+$") ~= nil
end

local function normalize_repo(value)
  if type(value) ~= "string" then
    return nil
  end

  local owner, repo = value:match("^([%w_.-]+)/([%w_.-]+)$")
  if not owner then
    owner, repo = value:match("^https://github%.com/([%w_.-]+)/([%w_.-]+)%.git$")
  end
  if not owner then
    owner, repo = value:match("^https://github%.com/([%w_.-]+)/([%w_.-]+)$")
  end
  if not owner then
    owner, repo = value:match("^git@github%.com:([%w_.-]+)/([%w_.-]+)%.git$")
  end
  if not owner or not valid_component(owner) or not valid_component(repo) then
    return nil
  end

  return owner .. "/" .. repo
end

local function plugin_name(repo, spec)
  if spec.name and valid_component(spec.name) then
    return spec.name
  end
  return repo:match("([^/]+)$")
end

local function plugin_paths(plugin)
  local data = vim.fn.stdpath("data")
  local basename = plugin.repo:match("([^/]+)$")
  local candidates = {
    vim.fs.joinpath(data, "easyvim", "plugins", plugin.name),
    vim.fs.joinpath(data, "lazy", plugin.name),
    vim.fs.joinpath(data, "lazy", basename),
  }

  local seen = {}
  for _, path in ipairs(candidates) do
    if not seen[path] then
      seen[path] = true
      if vim.fn.isdirectory(path) == 1 then
        return path
      end
    end
  end
end

local function managed_path(plugin)
  return vim.fs.joinpath(
    vim.fn.stdpath("data"),
    "easyvim",
    "plugins",
    plugin.name
  )
end

local function user_plugin_dir()
  return vim.fs.joinpath(vim.fn.stdpath("config"), "lua", "myconfig", "plugins", "user")
end

local function is_user_plugin_file(path)
  local directory = vim.fs.normalize(user_plugin_dir()):gsub("\\", "/"):lower()
  local normalized_path = vim.fs.normalize(path):gsub("\\", "/"):lower()
  return normalized_path == directory or normalized_path:sub(1, #directory + 1) == directory .. "/"
end

local function add_spec(spec, source_file, specs, by_repo)
  if type(spec) == "string" then
    spec = { spec }
  end
  if type(spec) ~= "table" then
    notify("Invalid plugin specification in " .. source_file, vim.log.levels.ERROR)
    return
  end

  local repo = normalize_repo(spec[1] or spec.repo or spec.url)
  if not repo then
    notify("Invalid GitHub repository in " .. source_file, vim.log.levels.ERROR)
    return
  end

  local existing = by_repo[repo]
  if existing then
    if is_user_plugin_file(source_file) and not existing.user_source_file then
      existing.spec = vim.tbl_deep_extend("force", existing.spec, spec)
      existing.user_source_file = source_file
      existing.source_file = source_file
      existing.is_override = true
      if spec.name then
        existing.name = plugin_name(repo, spec)
      end
      return
    end
    notify("Duplicate plugin specification for " .. repo, vim.log.levels.ERROR)
    return
  end

  local plugin = {
    repo = repo,
    name = plugin_name(repo, spec),
    spec = spec,
    source_file = source_file,
    user_source_file = is_user_plugin_file(source_file) and source_file or nil,
    is_override = false,
  }
  plugin.path = plugin_paths(plugin)
  specs[#specs + 1] = plugin
  by_repo[repo] = plugin
end

local function collect_specs()
  local specs = {}
  local by_repo = {}
  local config = vim.fn.stdpath("config")
  local plugin_dir = vim.fs.joinpath(config, "lua", "myconfig", "plugins")

  for filename, kind in vim.fs.dir(plugin_dir) do
    if kind == "file" and filename:match("%.lua$") then
      local module = "myconfig.plugins." .. filename:gsub("%.lua$", "")
      local ok, result = pcall(require, module)
      if not ok then
        notify("Could not load " .. module .. ": " .. tostring(result), vim.log.levels.ERROR)
      elseif type(result) == "table" then
        for _, spec in ipairs(result) do
          add_spec(spec, vim.fs.joinpath(plugin_dir, filename), specs, by_repo)
        end
      end
    end
  end

  local user_dir = vim.fs.joinpath(plugin_dir, "user")
  if vim.fn.isdirectory(user_dir) == 1 then
    local files = {}
    for filename, kind in vim.fs.dir(user_dir) do
      if kind == "file" and filename:match("%.lua$") then
        files[#files + 1] = filename
      end
    end
    table.sort(files)

    for _, filename in ipairs(files) do
      local path = vim.fs.joinpath(user_dir, filename)
      local ok, result = pcall(dofile, path)
      if not ok then
        notify("Could not load " .. path .. ": " .. tostring(result), vim.log.levels.ERROR)
      elseif type(result) == "table" then
        for _, spec in ipairs(result) do
          add_spec(spec, path, specs, by_repo)
        end
      end
    end
  end

  local index = 1
  while index <= #specs do
    local plugin = specs[index]
    local dependencies = plugin.spec.dependencies or {}
    if type(dependencies) == "string" then
      dependencies = { dependencies }
    end
    for _, dependency in ipairs(dependencies) do
      local dependency_spec = type(dependency) == "table" and dependency or { dependency }
      local repo = normalize_repo(dependency_spec[1])
      if repo and not by_repo[repo] then
        add_spec(dependency_spec, plugin.source_file, specs, by_repo)
      end
    end
    index = index + 1
  end

  table.sort(specs, function(a, b)
    return a.repo < b.repo
  end)
  return specs, by_repo
end

local function dependency_repos(plugin, by_repo)
  local dependencies = plugin.spec.dependencies or {}
  if type(dependencies) == "string" then
    dependencies = { dependencies }
  end

  local result = {}
  for _, dependency in ipairs(dependencies) do
    local repo = type(dependency) == "table" and normalize_repo(dependency[1]) or normalize_repo(dependency)
    if repo and by_repo[repo] then
      result[#result + 1] = repo
    elseif repo then
      notify(
        plugin.repo .. " depends on " .. repo .. ", which is not configured. Add it to a plugin spec.",
        vim.log.levels.WARN
      )
    end
  end
  return result
end

local function ordered_plugins(specs, by_repo)
  local ordered, visited, visiting = {}, {}, {}

  local function visit(plugin)
    if visited[plugin.repo] then
      return
    end
    if visiting[plugin.repo] then
      notify("Circular plugin dependency involving " .. plugin.repo, vim.log.levels.ERROR)
      return
    end
    visiting[plugin.repo] = true
    for _, repo in ipairs(dependency_repos(plugin, by_repo)) do
      visit(by_repo[repo])
    end
    visiting[plugin.repo] = nil
    visited[plugin.repo] = true
    ordered[#ordered + 1] = plugin
  end

  for _, plugin in ipairs(specs) do
    visit(plugin)
  end
  return ordered
end

local function plugin_script_files(plugin, extension, directory)
  directory = directory or "plugin"
  local files, seen = {}, {}
  for _, pattern in ipairs({ directory .. "/*." .. extension, directory .. "/**/*." .. extension }) do
    for _, path in ipairs(vim.fn.globpath(plugin.path, pattern, false, true)) do
      if not seen[path] then
        seen[path] = true
        files[#files + 1] = path
      end
    end
  end
  table.sort(files)
  return files
end

local function call_plugin_function(plugin, name, callback)
  if type(callback) ~= "function" then
    return
  end
  local ok, err = pcall(callback, plugin.spec, plugin.spec.opts)
  if not ok then
    notify(plugin.repo .. " " .. name .. " failed: " .. tostring(err), vim.log.levels.ERROR)
  end
end

local function setup_plugin(plugin)
  local spec = plugin.spec
  if type(spec.config) == "function" then
    call_plugin_function(plugin, "config", spec.config)
  elseif spec.opts ~= nil then
    local module = spec.main or plugin.name:gsub("%.nvim$", "")
    local ok, plugin_module = pcall(require, module)
    if not ok then
      notify(plugin.repo .. " setup module '" .. module .. "' was not found: " .. tostring(plugin_module), vim.log.levels.ERROR)
      return
    end
    if type(plugin_module.setup) ~= "function" then
      notify(plugin.repo .. " has opts but no setup() function in module '" .. module .. "'", vim.log.levels.ERROR)
      return
    end
    local configured, err = pcall(plugin_module.setup, spec.opts)
    if not configured then
      notify(plugin.repo .. " setup failed: " .. tostring(err), vim.log.levels.ERROR)
    end
  end

  for _, key in ipairs(spec.keys or {}) do
    if type(key) == "table" and type(key[1]) == "string" and key[2] ~= nil then
      local mode = key.mode or "n"
      vim.keymap.set(mode, key[1], key[2], {
        desc = key.desc,
        silent = true,
      })
    end
  end
end

local function load_plugins()
  local specs, by_repo = collect_specs()
  M.plugins = specs
  M.by_repo = by_repo

  local order = ordered_plugins(specs, by_repo)
  local available = {}
  local missing = {}
  for _, plugin in ipairs(order) do
    plugin.path = plugin_paths(plugin)
    if plugin.spec.enabled == false then
      available[plugin.repo] = false
    elseif plugin.path then
      available[plugin.repo] = true
      vim.opt.rtp:prepend(plugin.path)
    else
      missing[#missing + 1] = plugin.repo
    end
  end

  local ready = {}
  for _, plugin in ipairs(order) do
    ready[plugin.repo] = available[plugin.repo] == true
    if ready[plugin.repo] then
      for _, repo in ipairs(dependency_repos(plugin, by_repo)) do
        if not ready[repo] then
          ready[plugin.repo] = false
          notify(
            "Skipped " .. plugin.repo .. " because dependency " .. repo .. " is not installed.",
            vim.log.levels.WARN
          )
          break
        end
      end
    end
  end

  for _, plugin in ipairs(order) do
    if ready[plugin.repo] then
      call_plugin_function(plugin, "init", plugin.spec.init)
    end
  end

  for _, plugin in ipairs(order) do
    if ready[plugin.repo] then
      for _, path in ipairs(plugin_script_files(plugin, "vim")) do
        local ok, err = pcall(vim.cmd, { cmd = "source", args = { path } })
        if not ok then
          notify(plugin.repo .. " script failed: " .. tostring(err), vim.log.levels.ERROR)
        end
      end
      for _, path in ipairs(plugin_script_files(plugin, "lua")) do
        local chunk, err = loadfile(path)
        if not chunk then
          notify(plugin.repo .. " script failed: " .. tostring(err), vim.log.levels.ERROR)
        else
          local ok, script_error = pcall(chunk)
          if not ok then
            notify(plugin.repo .. " script failed: " .. tostring(script_error), vim.log.levels.ERROR)
          end
        end
      end
    end
  end

  for _, plugin in ipairs(order) do
    if ready[plugin.repo] then
      setup_plugin(plugin)
    end
  end

  for _, plugin in ipairs(order) do
    if ready[plugin.repo] then
      local after = vim.fs.joinpath(plugin.path, "after")
      if vim.fn.isdirectory(after) == 1 then
        vim.opt.rtp:append(after)
      end
    end
  end
  for _, plugin in ipairs(order) do
    if ready[plugin.repo] then
      for _, path in ipairs(plugin_script_files(plugin, "vim", "after/plugin")) do
        local ok, err = pcall(vim.cmd, { cmd = "source", args = { path } })
        if not ok then
          notify(plugin.repo .. " after script failed: " .. tostring(err), vim.log.levels.ERROR)
        end
      end
      for _, path in ipairs(plugin_script_files(plugin, "lua", "after/plugin")) do
        local chunk, err = loadfile(path)
        if not chunk then
          notify(plugin.repo .. " after script failed: " .. tostring(err), vim.log.levels.ERROR)
        else
          local ok, script_error = pcall(chunk)
          if not ok then
            notify(plugin.repo .. " after script failed: " .. tostring(script_error), vim.log.levels.ERROR)
          end
        end
      end
    end
  end

  if #missing > 0 then
    vim.schedule(function()
      notify(
        #missing .. " plugin(s) are not installed. Run :PluginManager sync to install them.",
        vim.log.levels.WARN
      )
    end)
  end
end

local function community_file()
  return vim.fs.joinpath(vim.fn.stdpath("config"), "lua", "myconfig", "plugins", "community.lua")
end

local function add_to_community(repo)
  local path = community_file()
  local lines = vim.fn.readfile(path)
  if #lines == 0 then
    notify("Could not read " .. path, vim.log.levels.ERROR)
    return false
  end

  local escaped_repo = vim.pesc(repo)
  for _, line in ipairs(lines) do
    if line:match('^%s*["\']' .. escaped_repo .. '["\']%s*,?%s*$') then
      return true
    end
  end

  local closing_line
  for index = #lines, 1, -1 do
    if lines[index]:match("%S") then
      closing_line = index
      break
    end
  end
  if not closing_line or not lines[closing_line]:match("^%s*}%s*$") then
    notify("community.lua must end with the plugin list's closing brace.", vim.log.levels.ERROR)
    return false
  end

  table.insert(lines, closing_line, '  "' .. repo .. '",')
  if vim.fn.writefile(lines, path) ~= 0 then
    notify("Could not update " .. path, vim.log.levels.ERROR)
    return false
  end
  return true
end

local function remove_from_community(repo)
  local path = community_file()
  local lines = vim.fn.readfile(path)
  local kept, removed = {}, false
  local escaped_repo = vim.pesc(repo)
  for _, line in ipairs(lines) do
    if not line:match('^%s*["\']' .. escaped_repo .. '["\']%s*,?%s*$') then
      kept[#kept + 1] = line
    else
      removed = true
    end
  end
  if not removed then
    return false
  end
  if vim.fn.writefile(kept, path) ~= 0 then
    notify("Could not update " .. path, vim.log.levels.ERROR)
    return false
  end
  return true
end

local function close_progress_window(state)
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_close(state.win, true)
  end
  state.win = nil
end

local function popup(lines, title, on_close, enter)
  local buf = vim.api.nvim_create_buf(false, true)
  local width = math.min(68, math.max(20, vim.o.columns - 4))
  local height = math.min(#lines, math.max(1, vim.o.lines - 6))
  local win = vim.api.nvim_open_win(buf, enter ~= false, {
    relative = "editor",
    row = math.max(0, math.floor((vim.o.lines - height) / 2) - 1),
    col = math.max(0, math.floor((vim.o.columns - width) / 2)),
    width = width,
    height = height,
    style = "minimal",
    border = "rounded",
    title = " " .. title .. " ",
    title_pos = "center",
  })
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].modifiable = false
  vim.wo[win].wrap = false
  vim.wo[win].cursorline = false

  local function close()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    if on_close then
      on_close()
    end
  end
  for _, key in ipairs({ "q", "<CR>", "<Esc>" }) do
    vim.keymap.set("n", key, close, { buffer = buf, silent = true, nowait = true })
  end
  return buf, win
end

local function format_duration(seconds)
  seconds = math.max(0, math.floor(seconds))
  if seconds < 60 then
    return seconds .. "s"
  end
  return string.format("%dm %02ds", math.floor(seconds / 60), seconds % 60)
end

local function render_progress()
  local state = progress
  if not state or state.hidden then
    return
  end
  if state.win and not vim.api.nvim_win_is_valid(state.win) then
    state.win = nil
    state.hidden = true
    return
  end

  local fraction = (state.completed + state.plugin_fraction) / state.total
  local percent = math.min(99, math.floor(fraction * 100))
  state.max_fraction = math.max(state.max_fraction, fraction)
  local elapsed = (vim.uv.hrtime() - state.started_at) / 1e9
  local remaining
  if not state.eta_unknown and state.max_fraction >= 0.05 and elapsed >= 2 then
    remaining = elapsed * (1 - state.max_fraction) / state.max_fraction
  end

  local bar_width = math.max(10, math.min(32, vim.o.columns - 38))
  local filled = math.floor(bar_width * percent / 100)
  local bar = string.rep("#", filled) .. string.rep("-", bar_width - filled)
  local lines = {
    string.format("%s plugins (%d/%d)", state.action, state.index, state.total),
    "",
    state.repo,
    state.phase,
    "",
    string.format("[%s] %d%%", bar, percent),
    "Elapsed: " .. format_duration(elapsed)
      .. "    Remaining: " .. (remaining and format_duration(remaining) or "calculating..."),
    "",
    "Press q to hide progress",
  }

  if not state.win then
    local _, win = popup(lines, "EasyVim Plugin Manager", function()
      if progress == state then
        state.hidden = true
        state.win = nil
      end
    end, false)
    state.win = win
    state.buf = vim.api.nvim_win_get_buf(win)
  else
    vim.bo[state.buf].modifiable = true
    vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
    vim.bo[state.buf].modifiable = false
  end
end

local function begin_progress(action, total)
  if progress and progress.timer then
    progress.timer:stop()
    progress.timer:close()
  end
  progress = {
    action = action == "clone" and "Installing" or "Updating",
    total = total,
    index = 1,
    repo = "",
    phase = "Preparing...",
    plugin_fraction = 0,
    completed = 0,
    max_fraction = 0,
    started_at = vim.uv.hrtime(),
    hidden = false,
  }
  progress.timer = vim.uv.new_timer()
  progress.timer:start(1000, 1000, function()
    vim.schedule(render_progress)
  end)
  render_progress()
end

local function set_progress_plugin(index, total, plugin, action)
  if not progress then
    begin_progress(action, total)
  end
  progress.index = index
  progress.repo = plugin.repo
  progress.phase = action == "clone" and "Connecting to GitHub..." or "Checking for updates..."
  progress.plugin_fraction = 0
  progress.eta_unknown = false
  render_progress()
end

local function observe_git_progress(data)
  if not progress or progress.eta_unknown then
    return
  end
  for _, text in ipairs(data) do
    for line in text:gmatch("[^\r\n]+") do
      local phase, value = line:match("([%a ]+):%s*(%d+)%%")
      if value then
        local fraction = tonumber(value) / 100
        phase = vim.trim(phase):lower()
        if phase:find("receiving", 1, true) or phase:find("remote", 1, true) then
          progress.plugin_fraction = 0.1 + fraction * 0.78
        elseif phase:find("resolving", 1, true) then
          progress.plugin_fraction = 0.88 + fraction * 0.1
        elseif phase:find("checking out", 1, true) or phase:find("updating files", 1, true) then
          progress.plugin_fraction = 0.98
        else
          progress.plugin_fraction = math.max(progress.plugin_fraction, fraction * 0.1)
        end
        progress.phase = phase:gsub("^%l", string.upper) .. "..."
      else
        progress.phase = line
      end
    end
  end
  render_progress()
end

local function set_progress_phase(phase, fraction)
  if not progress then
    return
  end
  progress.phase = phase
  progress.eta_unknown = phase:find("build", 1, true) ~= nil
  progress.plugin_fraction = math.max(progress.plugin_fraction, fraction or 0)
  render_progress()
end

local function finish_progress(action, completed, failures)
  local state = progress
  if state then
    close_progress_window(state)
    if state.timer then
      state.timer:stop()
      state.timer:close()
    end
  end
  progress = nil

  local label = action == "clone" and "Installation" or "Update"
  local lines = {
    #failures == 0 and (label .. " completed successfully.") or (label .. " finished with errors."),
    "",
    string.format("Successful: %d    Failed: %d", #completed, #failures),
  }
  for index = 1, math.min(#completed, 5) do
    lines[#lines + 1] = "  + " .. completed[index]
  end
  for index = 1, math.min(#failures, 5) do
    lines[#lines + 1] = "  ! " .. failures[index]
  end
  if #completed + #failures > 10 then
    lines[#lines + 1] = "  ... and more"
  end
  lines[#lines + 1] = ""
  lines[#lines + 1] = "Press q, Enter, or Esc to close"
  popup(lines, #failures == 0 and "Success" or "Finished with errors")
end

local function start_job(command, options, on_output, callback)
  local stderr = {}
  options.stdout_buffered = false
  options.stderr_buffered = false
  options.on_stdout = function(_, data)
    if on_output then
      on_output(data)
    end
  end
  options.on_stderr = function(_, data)
    for _, line in ipairs(data) do
      if line ~= "" then
        stderr[#stderr + 1] = line
      end
    end
    if on_output then
      on_output(data)
    end
  end
  options.on_exit = function(_, code)
    vim.schedule(function()
      callback(code, table.concat(stderr, "\n"))
    end)
  end

  local ok, job = pcall(vim.fn.jobstart, command, options)
  if not ok or job <= 0 then
    callback(nil, "Could not start process" .. (ok and " (jobstart returned " .. job .. ")" or ": " .. tostring(job)))
  end
end

local function run_build(plugin, path, callback)
  local build = plugin.spec.build
  if build == nil then
    callback(true)
    return
  end
  if type(build) ~= "table" or #build == 0 then
    callback(false, "build must be a list of executable arguments")
    return
  end
  for _, argument in ipairs(build) do
    if type(argument) ~= "string" then
      callback(false, "build arguments must be strings")
      return
    end
  end

  local cwd = path
  if plugin.spec.build_cwd then
    cwd = vim.fs.joinpath(path, plugin.spec.build_cwd)
  end
  if vim.fn.isdirectory(cwd) ~= 1 then
    callback(false, "build directory does not exist: " .. cwd)
    return
  end

  local command = vim.deepcopy(build)
  if vim.fn.has("win32") == 1 and command[1] == "npm" then
    local npm_path = vim.fn.exepath("npm")
    local node_path = vim.fn.exepath("node")
    local npm_cli = vim.fs.joinpath(vim.fs.dirname(npm_path), "node_modules", "npm", "bin", "npm-cli.js")
    if npm_path == "" or node_path == "" or vim.fn.filereadable(npm_cli) ~= 1 then
      callback(false, "could not locate Node.js and the npm CLI")
      return
    end
    local npm_args = {}
    for index = 2, #command do
      npm_args[#npm_args + 1] = command[index]
    end
    command = { node_path, npm_cli }
    vim.list_extend(command, npm_args)
  end

  set_progress_phase("Building plugin...", 0.99)
  start_job(command, { cwd = cwd }, nil, function(code, stderr)
    if code == 0 then
      callback(true)
    else
      callback(false, stderr ~= "" and stderr or ("build exited with code " .. tostring(code)))
    end
  end)
end

local function run_git(plugin, action, callback)
  local path = plugin.path or plugin_paths(plugin)
  if action == "clone" then
    path = managed_path(plugin)
    vim.fn.mkdir(vim.fs.dirname(path), "p")
    local command = { "git", "clone", "--progress", "--filter=blob:none", "--single-branch" }
    if plugin.spec.branch then
      vim.list_extend(command, { "--branch", plugin.spec.branch })
    end
    vim.list_extend(command, { "https://github.com/" .. plugin.repo .. ".git", path })

    start_job(command, {}, observe_git_progress, function(code, stderr)
      if code ~= 0 then
        callback(false, stderr ~= "" and stderr or ("git clone exited with code " .. tostring(code)))
        return
      end
      plugin.path = path
      set_progress_phase("Git checkout complete. Running build...", 0.99)
      run_build(plugin, path, callback)
    end)
    return
  end

  if not path then
    callback(false, "plugin is not installed")
    return
  end
  start_job({ "git", "-C", path, "pull", "--progress", "--ff-only" }, {}, observe_git_progress, function(code, stderr)
    if code ~= 0 then
      callback(false, stderr ~= "" and stderr or ("git pull exited with code " .. tostring(code)))
      return
    end
    set_progress_phase("Git update complete. Running build...", 0.99)
    run_build(plugin, path, callback)
  end)
end

local function run_sequence(plugins, action, callback)
  local index, completed_index = 1, 0
  local failures = {}
  local completed = {}
  begin_progress(action, #plugins)

  local function next_plugin()
    local plugin = plugins[index]
    local plugin_index = index
    index = index + 1
    if not plugin then
      finish_progress(action, completed, failures)
      callback(failures)
      return
    end

    set_progress_plugin(plugin_index, #plugins, plugin, action)
    run_git(plugin, action, function(ok, err)
      if not ok then
        failures[#failures + 1] = plugin.repo .. ": " .. err
        notify(plugin.repo .. " failed: " .. err, vim.log.levels.ERROR)
      else
        completed[#completed + 1] = plugin.repo
      end
      if progress then
        completed_index = completed_index + 1
        progress.completed = completed_index
        progress.plugin_fraction = 0
        render_progress()
      end
      next_plugin()
    end)
  end

  next_plugin()
end

local function install_repo(repo_value)
  local repo = normalize_repo(repo_value)
  if not repo then
    notify("Use a GitHub repository such as owner/name.", vim.log.levels.ERROR)
    return
  end

  local plugin = M.by_repo[repo]
  if not plugin then
    if not add_to_community(repo) then
      return
    end
    plugin = {
      repo = repo,
      name = repo:match("([^/]+)$"),
      spec = { repo },
      source_file = community_file(),
    }
    M.by_repo[repo] = plugin
    M.plugins[#M.plugins + 1] = plugin
  end

  plugin.path = plugin_paths(plugin)
  if plugin.path then
    notify(repo .. " is already installed. Restart Neovim to load it.")
    return
  end

  begin_progress("clone", 1)
  set_progress_plugin(1, 1, plugin, "clone")
  run_git(plugin, "clone", function(ok, err)
    if not ok then
      finish_progress("clone", {}, { repo .. ": " .. err })
      notify(repo .. " installation failed: " .. err, vim.log.levels.ERROR)
    else
      finish_progress("clone", { repo }, {})
      notify(repo .. " installed. Restart Neovim to load it.")
    end
  end)
end

local function sync_missing()
  local missing = {}
  for _, plugin in ipairs(M.plugins) do
    plugin.path = plugin_paths(plugin)
    if plugin.spec.enabled ~= false and not plugin.path then
      missing[#missing + 1] = plugin
    end
  end
  if #missing == 0 then
    notify("All configured plugins are installed.")
    return
  end

  notify("Installing " .. #missing .. " missing plugin(s)...")
  run_sequence(missing, "clone", function(failures)
    if #failures == 0 then
      notify("Plugin sync complete. Restart Neovim to load newly installed plugins.")
    else
      notify(#failures .. " plugin(s) failed. See the error notifications above.", vim.log.levels.ERROR)
    end
  end)
end

local function update_plugins(repo_value)
  local plugins = {}
  if repo_value and repo_value ~= "all" then
    local repo = normalize_repo(repo_value)
    if not repo or not M.by_repo[repo] then
      notify("That repository is not in the configured plugin list.", vim.log.levels.ERROR)
      return
    end
    local plugin = M.by_repo[repo]
    plugin.path = plugin_paths(plugin)
    if not plugin.path then
      notify(repo .. " is not installed. Run :PluginManager install " .. repo)
      return
    end
    plugins[1] = plugin
  else
    for _, plugin in ipairs(M.plugins) do
      plugin.path = plugin_paths(plugin)
      if plugin.path then
        plugins[#plugins + 1] = plugin
      end
    end
  end

  if #plugins == 0 then
    notify("No installed plugins to update.")
    return
  end
  notify("Updating " .. #plugins .. " plugin(s)...")
  run_sequence(plugins, "update", function(failures)
    if #failures == 0 then
      notify("Plugin update complete. Restart Neovim if a plugin changed.")
    else
      notify(#failures .. " plugin(s) failed to update.", vim.log.levels.ERROR)
    end
  end)
end

local function remove_plugin(repo_value)
  local repo = normalize_repo(repo_value)
  local plugin = repo and M.by_repo[repo]
  if not plugin then
    notify("That repository is not in the configured plugin list.", vim.log.levels.ERROR)
    return
  end

  local in_community = plugin.source_file == community_file()
  local in_user_dir = plugin.source_file
    and plugin.source_file:find(vim.fs.joinpath(vim.fn.stdpath("config"), "lua", "myconfig", "plugins", "user"), 1, true) == 1
  if not plugin.is_override and not in_community and not in_user_dir then
    notify("Built-in plugin specs are not removed automatically. Edit " .. plugin.source_file, vim.log.levels.WARN)
    return
  end

  vim.ui.select({ "Remove plugin configuration", "Cancel" }, {
    prompt = "Remove " .. repo .. " from your configuration?",
  }, function(choice)
    if choice ~= "Remove plugin configuration" then
      return
    end

    local removed
    if in_community then
      removed = remove_from_community(repo)
    else
      removed = vim.fn.delete(plugin.source_file) == 0
      if not removed then
        notify("Could not remove " .. plugin.source_file, vim.log.levels.ERROR)
        return
      end
    end
    if not removed then
      notify("Could not remove " .. repo .. " from the plugin configuration.", vim.log.levels.ERROR)
      return
    end

    if plugin.is_override then
      notify("Removed the individual settings for " .. repo .. ". Its base configuration remains; restart Neovim.")
      return
    end

    local installed_path = managed_path(plugin)
    if plugin.path == installed_path and vim.fn.isdirectory(installed_path) == 1 then
      local delete_result = vim.fn.delete(installed_path, "rf")
      if delete_result ~= 0 then
        notify("Removed plugin spec, but could not delete " .. installed_path, vim.log.levels.ERROR)
        return
      end
    end
    notify(repo .. " removed from the config. Restart Neovim to finish unloading it.")
  end)
end

local function create_plugin_config(repo_value)
  local repo = normalize_repo(repo_value)
  if not repo then
    notify("Use a GitHub repository such as owner/name.", vim.log.levels.ERROR)
    return
  end
  if M.by_repo[repo] then
    notify(repo .. " already has a plugin specification.", vim.log.levels.WARN)
    return
  end

  local owner, name = repo:match("^([^/]+)/([^/]+)$")
  local directory = user_plugin_dir()
  vim.fn.mkdir(directory, "p")
  local path = vim.fs.joinpath(directory, owner .. "_" .. name .. ".lua")
  if vim.fn.filereadable(path) == 1 then
    notify("A plugin specification already exists at " .. path, vim.log.levels.ERROR)
    return
  end

  local contents = {
    "return {",
    "  {",
    '    "' .. repo .. '",',
    "    -- Add opts, dependencies, or a config function here.",
    "  },",
    "}",
  }
  if vim.fn.writefile(contents, path) ~= 0 then
    notify("Could not create " .. path, vim.log.levels.ERROR)
    return
  end
  local plugin = {
    repo = repo,
    name = name,
    spec = { repo },
    source_file = path,
  }
  M.by_repo[repo] = plugin
  M.plugins[#M.plugins + 1] = plugin
  notify("Created " .. path .. ". Installing it now; restart Neovim to load its config.")
  install_repo(repo)
  vim.cmd("edit " .. vim.fn.fnameescape(path))
end

local function list_plugins()
  if #M.plugins == 0 then
    notify("No plugin specifications found.")
    return
  end
  local entries = {}
  for _, plugin in ipairs(M.plugins) do
    plugin.path = plugin_paths(plugin)
    entries[#entries + 1] = {
      plugin = plugin,
      label = plugin.repo .. (plugin.path and "  [installed]" or "  [missing]"),
    }
  end
  vim.ui.select(entries, {
    prompt = "Configured plugins",
    format_item = function(entry)
      return entry.label
    end,
  }, function(entry)
    if entry then
      vim.cmd("edit " .. vim.fn.fnameescape(entry.plugin.source_file))
    end
  end)
end

local function open_plugin_config(plugin)
  local path = plugin.user_source_file
  if not path and is_user_plugin_file(plugin.source_file) then
    path = plugin.source_file
  end

  if not path then
    local owner, name = plugin.repo:match("^([^/]+)/([^/]+)$")
    path = vim.fs.joinpath(user_plugin_dir(), owner .. "_" .. name .. ".lua")
    if vim.fn.filereadable(path) ~= 1 then
      vim.fn.mkdir(user_plugin_dir(), "p")
      local contents = {
        "return {",
        "  {",
        '    "' .. plugin.repo .. '",',
        "    -- Add per-plugin opts, init, config, keys, or dependencies here.",
        "  },",
        "}",
      }
      if vim.fn.writefile(contents, path) ~= 0 then
        notify("Could not create " .. path, vim.log.levels.ERROR)
        return
      end
    end
    plugin.base_source_file = plugin.source_file
    plugin.source_file = path
    plugin.user_source_file = path
    plugin.is_override = true
    notify("Created an individual config for " .. plugin.repo .. ". Restart Neovim after editing it.")
  end

  if vim.fn.filereadable(path) ~= 1 then
    notify("Plugin configuration was not found: " .. path, vim.log.levels.ERROR)
    return
  end
  vim.cmd("edit " .. vim.fn.fnameescape(path))
end

local function open_plugin_help(plugin)
  local readmes = {
    "README.md",
    "readme.md",
    "README",
    "doc/" .. plugin.name .. ".txt",
  }
  for _, filename in ipairs(readmes) do
    local path = vim.fs.joinpath(plugin.path, filename)
    if vim.fn.filereadable(path) == 1 then
      vim.cmd("tabedit " .. vim.fn.fnameescape(path))
      return
    end
  end

  local url = "https://github.com/" .. plugin.repo
  local ok, err = pcall(vim.ui.open, url)
  if not ok then
    notify("Could not open plugin documentation: " .. tostring(err), vim.log.levels.ERROR)
  end
end

local function can_remove_plugin(plugin)
  local user_dir = vim.fs.joinpath(vim.fn.stdpath("config"), "lua", "myconfig", "plugins", "user")
  return plugin.is_override or (plugin.source_file == community_file()
    or (plugin.source_file and plugin.source_file:find(user_dir, 1, true) == 1)
  )
end

local function manage_plugin(plugin)
  plugin.path = plugin_paths(plugin)
  local status = plugin.path and "installed" or "not installed"
  local actions = {
    {
      name = "Help / plugin instructions",
      action = function()
        if plugin.path then
          open_plugin_help(plugin)
        else
          notify("Install this plugin first to read its bundled instructions.", vim.log.levels.WARN)
        end
      end,
    },
    {
      name = "Configure / edit plugin settings",
      action = function()
        open_plugin_config(plugin)
      end,
    },
    {
      name = "Update this plugin",
      action = function()
        if plugin.path then
          update_plugins(plugin.repo)
        else
          notify("Install this plugin first.", vim.log.levels.WARN)
        end
      end,
    },
    {
      name = "Remove plugin",
      action = function()
        if can_remove_plugin(plugin) then
          remove_plugin(plugin.repo)
        else
          notify("This is a built-in plugin. Open its config to remove or disable it.", vim.log.levels.WARN)
          open_plugin_config(plugin)
        end
      end,
    },
  }

  vim.ui.select(actions, {
    prompt = plugin.repo .. " (" .. status .. ") — choose an action",
    format_item = function(item)
      return item.name
    end,
  }, function(action)
    if action then
      action.action()
    end
  end)
end

local function manage_plugins()
  local entries = {}
  for _, plugin in ipairs(M.plugins) do
    plugin.path = plugin_paths(plugin)
    entries[#entries + 1] = {
      plugin = plugin,
      label = plugin.repo .. (plugin.path and "  [installed]" or "  [not installed]"),
    }
  end
  if #entries == 0 then
    notify("No plugin specifications found.")
    return
  end

  vim.ui.select(entries, {
    prompt = "My plugins — choose one for help, settings, update, or removal",
    format_item = function(entry)
      return entry.label
    end,
  }, function(entry)
    if entry then
      manage_plugin(entry.plugin)
    end
  end)
end

local function search_github()
  vim.ui.input({ prompt = "Search GitHub plugins: " }, function(query)
    if not query or query:match("^%s*$") then
      return
    end
    local command = {
      "curl",
      "--fail",
      "--silent",
      "--show-error",
      "--location",
      "--get",
      "--header",
      "Accept: application/vnd.github+json",
      "--header",
      "User-Agent: EasyVim-Plugin-Manager",
      "--data-urlencode",
      "q=" .. query .. " neovim plugin",
      "--data-urlencode",
      "sort=stars",
      "--data-urlencode",
      "order=desc",
      "--data-urlencode",
      "per_page=30",
      "https://api.github.com/search/repositories",
    }
    local ok, process = pcall(vim.system, command, { text = true }, function(result)
      vim.schedule(function()
        if result.code ~= 0 then
          local detail = result.stderr and result.stderr:gsub("%s+$", "") or ""
          notify("GitHub search failed." .. (detail ~= "" and " " .. detail or " Check curl, your connection, and the API rate limit."), vim.log.levels.ERROR)
          return
        end
        local decoded, response = pcall(vim.json.decode, result.stdout)
        if not decoded or type(response) ~= "table" then
          notify("GitHub returned an invalid response.", vim.log.levels.ERROR)
          return
        end
        if response.message then
          notify("GitHub: " .. response.message, vim.log.levels.ERROR)
          return
        end

        local results = {}
        for _, item in ipairs(response.items or {}) do
          local repo = normalize_repo(item.full_name)
          if repo then
            results[#results + 1] = {
              repo = repo,
              description = item.description or "No description",
              stars = item.stargazers_count or 0,
            }
          end
        end
        vim.ui.select(results, {
          prompt = "GitHub plugin repositories",
          format_item = function(item)
            return string.format("%s  |  %d stars  |  %s", item.repo, item.stars, item.description)
          end,
        }, function(item)
          if item then
            vim.ui.select({ "Install", "Create editable plugin config", "Cancel" }, {
              prompt = "What would you like to do with " .. item.repo .. "?",
            }, function(choice)
              if choice == "Install" then
                install_repo(item.repo)
              elseif choice == "Create editable plugin config" then
                create_plugin_config(item.repo)
              end
            end)
          end
        end)
      end)
    end)
    if not ok then
      notify("Could not start curl: " .. tostring(process), vim.log.levels.ERROR)
    end
  end)
end

local function show_catalog()
  vim.ui.select(catalog, {
    prompt = "Popular plugin categories",
    format_item = function(category)
      return category.name
    end,
  }, function(category)
    if not category then
      return
    end
    vim.ui.select(category.plugins, {
      prompt = category.name,
      format_item = function(plugin)
        return plugin.repo .. "  —  " .. plugin.description
      end,
    }, function(plugin)
      if plugin then
        vim.ui.select({ "Install", "Create editable plugin config", "Cancel" }, {
          prompt = "What would you like to do with " .. plugin.repo .. "?",
        }, function(choice)
          if choice == "Install" then
            install_repo(plugin.repo)
          elseif choice == "Create editable plugin config" then
            create_plugin_config(plugin.repo)
          end
        end)
      end
    end)
  end)
end

local function edit_plugin_specs()
  vim.cmd("edit " .. vim.fn.fnameescape(vim.fs.joinpath(
    vim.fn.stdpath("config"),
    "lua",
    "myconfig",
    "plugins",
    "community.lua"
  )))
end

local function show_manager_help()
  local lines = {
    "# Plugin Manager",
    "",
    "Choose **Manage my plugins** to select a plugin, then open its instructions, edit its settings, update it, or remove it.",
    "",
    "## Install",
    "- Browse popular plugins or search GitHub.",
    "- Choose a plugin and confirm installation.",
    "- Restart Neovim after installation.",
    "",
    "## Configure",
    "- Open Manage my plugins and select a plugin.",
    "- Choose Configure / edit plugin settings.",
    "- Each plugin can have an individual file under `plugins/user/`; these specs override built-in settings for that repository.",
    "- The generated spec supports `opts`, `init`, `config`, `keys`, `dependencies`, `branch`, and build commands. For plugins with a built-in custom `config` function, replace it in the individual spec if you want to change how `setup()` is called.",
    "- Check the plugin's README using Help / plugin instructions.",
    "",
    "## Update or remove",
    "- Select the plugin and choose Update this plugin or Remove plugin.",
    "- Only plugins in the community/user lists can be removed from this menu.",
    "- Restart Neovim after changing plugin configuration.",
    "",
    "## Commands",
    "- `:PluginManager sync` — install configured plugins that are missing.",
    "- `:PluginManager install owner/repo` — install from GitHub.",
    "- `:PluginManager update all` — update installed plugins.",
    "- `:PluginManager new owner/repo` — create an editable spec and install.",
    "",
    "## Progress",
    "- Install and update show Git transfer progress, elapsed time, and an estimated time remaining.",
    "- Build commands are shown as a separate step; their remaining time cannot be estimated from Git progress.",
    "- Completion opens a centered result window. Press `q`, Enter, or Esc to close it.",
  }
  vim.cmd("tabnew")
  local buffer = vim.api.nvim_get_current_buf()
  vim.bo[buffer].buftype = "nofile"
  vim.bo[buffer].bufhidden = "wipe"
  vim.bo[buffer].swapfile = false
  vim.bo[buffer].filetype = "markdown"
  vim.api.nvim_buf_set_name(buffer, "EasyVim Plugin Manager Help")
  vim.api.nvim_buf_set_lines(buffer, 0, -1, false, lines)
  vim.bo[buffer].modifiable = false
end

function M.open()
  local actions = {
    { name = "Install a plugin — popular list", action = show_catalog },
    { name = "Install a plugin — search GitHub", action = search_github },
    { name = "Install a plugin — enter owner/repo", action = function()
      vim.ui.input({ prompt = "GitHub repository (owner/name): " }, function(repo)
        if repo then
          install_repo(repo)
        end
      end)
    end },
    { name = "Manage my plugins — help / settings / update / remove", action = manage_plugins },
    { name = "Update all installed plugins", action = function()
      update_plugins("all")
    end },
    { name = "Install missing configured plugins", action = sync_missing },
    { name = "Help — how to use this menu", action = show_manager_help },
  }

  vim.ui.select(actions, {
    prompt = "EasyVim Plugin Manager",
    format_item = function(item)
      return item.name
    end,
  }, function(item)
    if item then
      item.action()
    end
  end)
end

function M.stats()
  local installed = 0
  for _, plugin in ipairs(M.plugins) do
    if plugin_paths(plugin) then
      installed = installed + 1
    end
  end
  return {
    installed = installed,
    total = #M.plugins,
    startuptime = M.started_at > 0 and (os.clock() - M.started_at) * 1000 or 0,
  }
end

local function run_command(args)
  local action = args[1] ~= "" and args[1] or "open"
  local argument = args[2]
  if action == "open" then
    M.open()
  elseif action == "list" then
    list_plugins()
  elseif action == "sync" or action == "install-missing" then
    sync_missing()
  elseif action == "install" then
    if argument then
      install_repo(argument)
    else
      vim.ui.input({ prompt = "GitHub repository (owner/name): " }, function(repo)
        if repo then
          install_repo(repo)
        end
      end)
    end
  elseif action == "update" then
    update_plugins(argument or "all")
  elseif action == "remove" then
    if argument then
      remove_plugin(argument)
    else
      M.open()
    end
  elseif action == "new" then
    if argument then
      create_plugin_config(argument)
    else
      vim.ui.input({ prompt = "GitHub repository (owner/name): " }, function(repo)
        if repo then
          create_plugin_config(repo)
        end
      end)
    end
  elseif action == "search" then
    search_github()
  elseif action == "edit" then
    edit_plugin_specs()
  elseif action == "help" then
    show_manager_help()
  else
    notify("Usage: :PluginManager [open|list|sync|install|update|remove|new|search|edit|help] [owner/repo|all]", vim.log.levels.ERROR)
  end
end

function M.setup()
  M.started_at = os.clock()
  vim.api.nvim_create_user_command("PluginManager", function(command)
    run_command(vim.split(vim.trim(command.args), "%s+"))
  end, {
    nargs = "*",
    desc = "Install, update, and configure plugins",
    complete = function(_, line)
      local actions = { "open", "list", "sync", "install", "update", "remove", "new", "search", "edit", "help" }
      local prefix = line:match("^%s*PluginManager%s+(%S*)$")
      if prefix == nil then
        return {}
      end
      return vim.tbl_filter(function(action)
        return action:find(prefix, 1, true) == 1
      end, actions)
    end,
  })
  vim.api.nvim_create_user_command("PluginBrowser", M.open, {
    desc = "Open the plugin manager interface",
  })
  vim.keymap.set("n", "<leader>pi", M.open, { desc = "Plugin manager" })
  load_plugins()
end

return M
