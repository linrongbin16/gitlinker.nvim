local tbl = require("gitlinker.commons.tbl")
local str = require("gitlinker.commons.str")
local num = require("gitlinker.commons.num")
local LogLevels = require("gitlinker.commons.logging").LogLevels
local logging = require("gitlinker.commons.logging")
local async = require("gitlinker.commons.async")

local configs = require("gitlinker.configs")
local range = require("gitlinker.range")
local linker = require("gitlinker.linker")
local highlight = require("gitlinker.highlight")

--- @param lk gitlinker.Linker
--- @param template string
--- @return string?
local function _url_template_engine(lk, template)
  local OPEN_BRACE = "{"
  local CLOSE_BRACE = "}"
  if str.empty(template) or tbl.tbl_empty(lk) then
    return nil
  end

  local logger = logging.get("gitlinker")

  --- @alias gitlinker.UrlTemplateExpr {plain:boolean,body:string}
  --- @type gitlinker.UrlTemplateExpr[]
  local exprs = {}

  local i = 1
  local n = string.len(template)
  while i <= n do
    local open_pos = str.find(template, OPEN_BRACE, i)
    if not open_pos then
      table.insert(exprs, { plain = true, body = string.sub(template, i) })
      break
    end
    table.insert(exprs, { plain = true, body = string.sub(template, i, open_pos - 1) })
    local close_pos = str.find(template, CLOSE_BRACE, open_pos + string.len(OPEN_BRACE))
    logger:ensure(
      type(close_pos) == "number" and close_pos > open_pos,
      string.format(
        "failed to evaluate url template(%s) at pos %d",
        vim.inspect(template),
        open_pos + string.len(OPEN_BRACE)
      )
    )
    table.insert(exprs, {
      plain = false,
      body = string.sub(template, open_pos + string.len(OPEN_BRACE), close_pos - 1),
    })
    -- logger.debug(
    --   "|routers.url_template| expressions:%s (%d-%d)",
    --   vim.inspect(exprs),
    --   vim.inspect(open_pos),
    --   vim.inspect(close_pos)
    -- )
    i = close_pos + string.len(CLOSE_BRACE)
  end
  -- logger.debug(
  --   "|routers.url_template| final expressions:%s",
  --   vim.inspect(exprs)
  -- )

  local results = {}
  for _, exp in ipairs(exprs) do
    if exp.plain then
      table.insert(results, exp.body)
    else
      local evaluated = vim.fn.luaeval(exp.body, {
        PROTOCOL = lk.protocol or "",
        USERNAME = lk.username or "",
        PASSWORD = lk.password or "",
        HOST = lk.host or "",
        PORT = lk.port or "",
        USER = lk.user or "",
        ORG = lk.org or "",
        REPO = str.endswith(lk.repo, ".git") and lk.repo:sub(1, #lk.repo - 4) or lk.repo,
        REV = lk.rev,
        FILE = lk.file,
        LSTART = lk.lstart,
        LEND = num.ge(lk.lend, lk.lstart) and lk.lend or lk.lstart,
        DEFAULT_BRANCH = str.not_empty(lk.default_branch) and lk.default_branch or "",
        CURRENT_BRANCH = str.not_empty(lk.current_branch) and lk.current_branch or "",
      })
      logger:debug(
        string.format(
          "|_url_template_engine| exp:%s, lk:%s, evaluated:%s",
          vim.inspect(exp.body),
          vim.inspect(lk),
          vim.inspect(evaluated)
        )
      )
      table.insert(results, evaluated)
    end
  end

  return table.concat(results, "")
end

--- @param lk gitlinker.Linker
--- @param p string
--- @param r string|function(lk:gitlinker.Linker):string?
--- @return string?
local function _worker(lk, p, r)
  if type(r) == "function" then
    return r(lk)
  elseif type(r) == "string" then
    return _url_template_engine(lk, r)
  else
    local logger = logging.get("gitlinker")
    logger:ensure(
      false,
      string.format("unsupported router %s on pattern %s", vim.inspect(r), vim.inspect(p))
    )
    return nil
  end
end

--- @alias gitlinker.Router fun(lk:gitlinker.Linker):string?
--- @param router_type string
--- @param lk gitlinker.Linker
--- @return string?
local function _router(router_type, lk)
  local logger = logging.get("gitlinker")
  local confs = configs.get()
  logger:ensure(
    type(confs._routers[router_type]) == "table",
    string.format("unknown router type %s!", vim.inspect(router_type))
  )
  logger:ensure(
    type(confs._routers[router_type].list_routers) == "table",
    string.format("invalid router type %s! 'list_routers' missing.", vim.inspect(router_type))
  )
  logger:ensure(
    type(confs._routers[router_type].map_routers) == "table",
    string.format("invalid router type %s! 'map_routers' missing.", vim.inspect(router_type))
  )

  for i, tuple in ipairs(confs._routers[router_type].list_routers) do
    if type(i) == "number" and type(tuple) == "table" and #tuple == 2 then
      local pattern = tuple[1]
      local route = tuple[2]
      -- logger:debug(
      --   "|_router| list i:%d, pattern_route_tuple:%s, match host:%s(%s), remote_url:%s(%s)",
      --   vim.inspect(i),
      --   vim.inspect(tuple),
      --   vim.inspect(string.match(lk.host, pattern)),
      --   vim.inspect(lk.host),
      --   vim.inspect(string.match(lk.remote_url, pattern)),
      --   vim.inspect(lk.remote_url)
      -- )
      if string.match(lk.host, pattern) or string.match(lk.remote_url, pattern) then
        -- logger:debug(
        --   "|_router| match-1 router:%s with pattern:%s",
        --   vim.inspect(route),
        --   vim.inspect(pattern)
        -- )
        return _worker(lk, pattern, route)
      end
    end
  end
  for pattern, route in pairs(confs._routers[router_type].map_routers) do
    if
      type(pattern) == "string"
      and string.len(pattern) > 0
      and (type(route) == "string" or type(route) == "function")
    then
      -- logger:debug(
      --   "|_router| table pattern:%s, match host:%s, remote_url:%s",
      --   vim.inspect(pattern),
      --   vim.inspect(lk.host),
      --   vim.inspect(lk.remote_url)
      -- )
      if string.match(lk.host, pattern) or string.match(lk.remote_url, pattern) then
        -- logger:debug(
        --   "|_router| match-2 router:%s with pattern:%s",
        --   vim.inspect(route),
        --   vim.inspect(pattern)
        -- )
        return _worker(lk, pattern, route)
      end
    end
  end
  logger:ensure(
    false,
    string.format("%s not support, please bind it in 'router'!", vim.inspect(lk.host))
  )
  return nil
end

--- @param lk gitlinker.Linker
--- @return string?
local function _browse(lk)
  return _router("browse", lk)
end

--- @param lk gitlinker.Linker
--- @return string?
local function _blame(lk)
  return _router("blame", lk)
end

--- @param opts {action:gitlinker.Action|boolean,router:gitlinker.Router,lstart:integer,lend:integer,message:boolean?,highlight_duration:integer?,remote:string?,file:string?,rev:string?}
local _link = function(opts)
  local confs = configs.get()
  local logger = logging.get("gitlinker")
  -- logger.debug("[link] merged opts: %s", vim.inspect(opts))

  local lk = linker.make_linker(opts.remote, opts.file, opts.rev)
  if not lk then
    return nil
  end
  lk.lstart = opts.lstart
  lk.lend = opts.lend

  if str.not_empty(opts.file) then
    lk.file = opts.file
    lk.file_changed = false
  end
  if str.not_empty(opts.rev) then
    lk.rev = opts.rev
  end

  async.schedule()
  local ok, url = pcall(opts.router, lk, true)
  -- logger:debug(
  --   "|link| ok:%s, url:%s, router:%s",
  --   vim.inspect(ok),
  --   vim.inspect(url),
  --   vim.inspect(opts.router)
  -- )
  logger:ensure(
    ok and str.not_empty(url),
    string.format(
      "fatal: failed to generate permanent url from remote (%s): %s",
      vim.inspect(lk.remote_url),
      vim.inspect(url)
    )
  )

  if opts.action then
    opts.action(url --[[@as string]])
  end

  local highlight_duration = confs.highlight_duration
  if type(opts.highlight_duration) == "number" then
    highlight_duration = opts.highlight_duration
  end
  if highlight_duration > 0 then
    highlight.show({ lstart = lk.lstart, lend = lk.lend })
    vim.defer_fn(highlight.clear, confs.highlight_duration)
  end

  local message = confs.message
  if type(opts.message) == "boolean" then
    message = opts.message
  end
  logger:debug(
    string.format(
      "|_link| message:%s, opts:%s, confs:%s",
      vim.inspect(message),
      vim.inspect(opts),
      vim.inspect(confs)
    )
  )
  if message then
    local msg = lk.file_changed and url .. " (lines can be wrong due to file change)" or url --[[@as string]]
    msg = msg:gsub("%%", "%%%%")
    logger:info(msg --[[@as string]])
  end

  return url
end

--- @type fun(opts:{action:gitlinker.Action?,router:gitlinker.Router,lstart:integer,lend:integer,remote:string?,file:string?,rev:string?}):string?
local _sync_link = async.sync(1, _link)

--- @param args string?
--- @return {router_type:string,remote:string?,file:string?,rev:string?}
local function _parse_args(args)
  args = args or ""

  local router_type = "browse"
  local remote = nil
  local file = nil
  local rev = nil
  if string.len(args) == 0 then
    return { router_type = router_type, remote = remote, file = file, rev = rev }
  end
  local args_splits = vim.split(args, " ", { plain = true, trimempty = true })
  for _, a in ipairs(args_splits) do
    if string.len(a) > 0 then
      if str.startswith(a, "remote=") then
        remote = a:sub(8)
      elseif str.startswith(a, "file=") then
        file = a:sub(6)
      elseif str.startswith(a, "rev=") then
        rev = a:sub(5)
      else
        router_type = a
      end
    end
  end
  return { router_type = router_type, remote = remote, file = file, rev = rev }
end

--- @param opts gitlinker.Options?
local function setup(opts)
  local confs = configs.setup(opts)

  -- logger
  logging.setup({
    name = "gitlinker",
    level = confs.debug and LogLevels.DEBUG or LogLevels.INFO,
    console_log = confs.console_log,
    file_log = confs.file_log,
    file_log_name = "gitlinker.log",
  })

  -- command
  vim.api.nvim_create_user_command(confs.command.name, function(command_opts)
    local r = range.make_range()
    local args = (type(command_opts.args) == "string" and string.len(command_opts.args) > 0)
        and vim.trim(command_opts.args)
      or nil
    -- logger:debug(
    --   "|setup| command opts:%s, parsed:%s, range:%s",
    --   vim.inspect(command_opts),
    --   vim.inspect(args),
    --   vim.inspect(r)
    -- )
    local lstart = math.min(r.lstart, r.lend, command_opts.line1, command_opts.line2)
    local lend = math.max(r.lstart, r.lend, command_opts.line1, command_opts.line2)
    local parsed = _parse_args(args)
    _sync_link({
      action = command_opts.bang and require("gitlinker.actions").system
        or require("gitlinker.actions").clipboard,
      router = function(lk)
        return _router(parsed.router_type, lk)
      end,
      lstart = lstart,
      lend = lend,
      remote = parsed.remote,
      file = parsed.file,
      rev = parsed.rev,
    })
  end, {
    nargs = "*",
    range = true,
    bang = true,
    desc = confs.command.desc,
    complete = function()
      local suggestions = {}
      for router_type, _ in pairs(confs._routers) do
        table.insert(suggestions, router_type)
      end
      table.sort(suggestions, function(a, b)
        return a < b
      end)
      return suggestions
    end,
  })

  -- Configure highlight group
  if confs.highlight_duration > 0 then
    local hl_group = "NvimGitLinkerHighlightTextObject"
    if not highlight.hl_group_exists(hl_group) then
      vim.api.nvim_set_hl(0, hl_group, { link = "Search" })
    end
  end
end

--- @param opts {router_type:string?,router:gitlinker.Router?,action:gitlinker.Action?,lstart:integer?,lend:integer?,message:boolean?,highlight_duration:integer?,remote:string?,file:string?,rev:string?}?
local function link_api(opts)
  opts = opts
    or {
      router_type = "browse",
      action = require("gitlinker.actions").clipboard,
    }

  opts.router_type = str.not_empty(opts.router_type) and opts.router_type or "browse"
  opts.action = vim.is_callable(opts.action) and opts.action
    or require("gitlinker.actions").clipboard
  opts.router = vim.is_callable(opts.router) and opts.router
    or function(lk)
      return _router(opts.router_type, lk)
    end

  if not num.ge(opts.lstart, 0) and not num.ge(opts.lend, 0) then
    local r = range.make_range()
    opts.lstart = math.min(r.lstart, r.lend)
    opts.lend = math.max(r.lstart, r.lend)
  end

  _sync_link({
    action = opts.action,
    router = opts.router,
    lstart = opts.lstart,
    lend = opts.lend,
    message = opts.message,
    highlight_duration = opts.highlight_duration,
    remote = opts.remote,
    file = opts.file,
    rev = opts.rev,
  })
end

local M = {
  _url_template_engine = _url_template_engine,
  _worker = _worker,
  _sync_link = _sync_link,
  _router = _router,
  _browse = _browse,
  _blame = _blame,

  setup = setup,
  link = link_api,
}

return M
