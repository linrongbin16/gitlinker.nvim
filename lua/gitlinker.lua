local types = require("gitlinker.types")
local log = require("gitlinker.log")
local async = require("gitlinker.async")

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
  if types.str_empty(template) or types.tbl_empty(lk) then
    return nil
  end

  --- @alias gitlinker.UrlTemplateExpr {plain:boolean,body:string}
  --- @type gitlinker.UrlTemplateExpr[]
  local exprs = {}

  local i = 1
  local n = string.len(template)
  while i <= n do
    local open_pos = types.str_search(template, OPEN_BRACE, i)
    if not open_pos then
      table.insert(exprs, { plain = true, body = string.sub(template, i) })
      break
    end
    table.insert(exprs, { plain = true, body = string.sub(template, i, open_pos - 1) })
    local close_pos = types.str_search(template, CLOSE_BRACE, open_pos + string.len(OPEN_BRACE))
    log.ensure(
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
        REPO = types.str_strip_suffix(lk.repo, ".git"),
        REV = lk.rev,
        FILE = lk.file,
        LSTART = lk.lstart,
        LEND = types.greater_equal(lk.lend, lk.lstart) and lk.lend or lk.lstart,
        DEFAULT_BRANCH = types.str_empty(lk.default_branch) and "" or lk.default_branch,
        CURRENT_BRANCH = types.str_empty(lk.current_branch) and "" or lk.current_branch,
      })
      log.debug(
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
    log.ensure(
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
  local confs = configs.get()
  log.ensure(
    type(confs._routers[router_type]) == "table",
    string.format("unknown router type %s!", vim.inspect(router_type))
  )
  log.ensure(
    type(confs._routers[router_type].list_routers) == "table",
    string.format("invalid router type %s! 'list_routers' missing.", vim.inspect(router_type))
  )
  log.ensure(
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
  log.ensure(
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

--- Whether `value` is a line number a file can have, i.e. a whole number of at
--- least 1.
---
--- A line number that fails this is worse than useless downstream: `#L0` and
--- `#L1.5` name no line of any file, so the remote answers with a 404, and a
--- float or an infinity makes `vim.fn.col()` raise `E805` while highlighting,
--- from inside the coroutine of `_void_link`, where nothing reports it.
---
--- @param value any
--- @return boolean
local function _is_line_number(value)
  -- A NaN fails every comparison, including `==` with itself, which the
  -- integrality test below relies on.
  return type(value) == "number"
    and value == value
    and value ~= math.huge
    and value ~= -math.huge
    and value >= 1
    and value == math.floor(value)
end

--- Turn a line number handed in by the caller into one a file can have.
---
--- Anything that is not a finite number (`nil`, an infinity, a NaN) is not a
--- line number at all, so it is dropped and the caller falls back to the
--- selection or the cursor line. A finite one is moved onto the first line when
--- it points before it, and rounded down when it holds a fraction.
---
--- The upper bound is deliberately left alone: the range can point at a file
--- named by `file`/`rev`, whose length is unknown here, and clamping it to the
--- current buffer would silently move the range to an unrelated place.
---
--- @param value integer?
--- @return integer?
local function _resolve_line_number(value)
  if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
    return nil
  end
  return math.max(1, math.floor(value))
end

--- Normalize the two ends of a line range into one a file can have.
---
--- The result always has both ends, with `lstart` not after `lend`:
---   - both given: only the order has to be fixed, a reversed range is the
---     same lines as its sorted form;
---   - one given: it names a single line, so it is also the other end;
---   - none given: use the current selection, or the cursor line.
---
--- An end that is not a line number at all (`nil`, an infinity, a NaN) is
--- dropped first, so a caller that only got one usable end still falls into
--- the "one given" case.
---
--- @param lstart integer?
--- @param lend integer?
--- @return integer lstart
--- @return integer lend
local function _normalize_range(lstart, lend)
  lstart = _resolve_line_number(lstart)
  lend = _resolve_line_number(lend)
  if lstart and lend then
    if lend < lstart then
      return lend, lstart
    end
    return lstart, lend
  elseif lstart then
    return lstart, lstart
  elseif lend then
    return lend, lend
  end
  local r = range.make_range()
  return math.min(r.lstart, r.lend), math.max(r.lstart, r.lend)
end

--- Resolve what to highlight, before the first `await` of `_link`.
---
--- `_link` yields to the event loop a few times before it draws anything, so
--- the line width has to be read up front: by the time `highlight.show()` runs,
--- the current buffer may belong to another file and the range would be sized
--- from whichever file the user switched to.
---
--- The range is already checked by `_link`: both ends are whole line numbers
--- and `lend` is not before `lstart`, so it is used as given.
---
--- @param opts {lstart:integer,lend:integer,highlight_duration:integer?}
--- @param confs gitlinker.Options
--- @return {start:[integer,integer],finish:[integer,integer],duration:integer}?
local function _highlight_target(opts, confs)
  local duration = confs.highlight_duration
  if type(opts.highlight_duration) == "number" then
    duration = opts.highlight_duration
  end
  if duration <= 0 then
    return nil
  end
  log.ensure(
    opts.lstart <= opts.lend,
    string.format("invalid lstart/lend: %s/%s", vim.inspect(opts.lstart), vim.inspect(opts.lend))
  )
  return {
    start = { opts.lstart - 1, 0 },
    -- `lend` is named explicitly: the one-argument form of `col()` measures
    -- whatever line the cursor happens to sit on, which is only the end line
    -- when the range is a single line.
    finish = { opts.lend - 1, vim.fn.col({ opts.lend, "$" }) },
    duration = duration,
  }
end

--- Render a value raised by user code as the one line the logger prints.
--- `error()` accepts any value, so a raised table or `nil` has to be turned
--- into text before it reaches `string.format()`.
--- @param err any
--- @return string
local function _error_message(err)
  if type(err) == "string" then
    return err
  end
  return vim.inspect(err)
end

--- @param opts {action:gitlinker.Action|boolean,router:gitlinker.Router,lstart:integer,lend:integer,message:boolean?,warn_on_file_change:boolean?,highlight_duration:integer?,remote:string?,file:string?,rev:string?}
--- @return string?
local _link = function(opts)
  local confs = configs.get()
  -- logger.debug("[link] merged opts: %s", vim.inspect(opts))

  -- `link()` and the `:GitLink` command both normalize the range before they
  -- reach this point, so the check only fires for a caller that hands `opts`
  -- to `_void_link` directly. It still has to be here: without it a missing
  -- end reaches `luaeval`, which turns it into `vim.NIL`, and the default
  -- templates then raise "attempt to compare two nil values" from inside the
  -- template instead of saying what was wrong.
  if
    not _is_line_number(opts.lstart)
    or not _is_line_number(opts.lend)
    or opts.lstart > opts.lend
  then
    log.err(
      string.format(
        "fatal: invalid line range: %s(lstart) - %s(lend)",
        vim.inspect(opts.lstart),
        vim.inspect(opts.lend)
      )
    )
    return nil
  end

  -- Read the buffer once, here, and hand it to everything below. `_link` yields
  -- to the event loop a few times, and the user may open another file in the
  -- meantime: anything that goes back to "the current buffer" after the first
  -- `await` links, highlights and measures the file the user switched to.
  local bufnr = vim.api.nvim_get_current_buf()

  local highlight_target = _highlight_target(opts, confs)

  local lk, lk_err = linker.make_linker(bufnr, opts.remote, opts.file, opts.rev)
  if not lk then
    if lk_err then
      log.err(lk_err)
    end
    return nil
  end
  lk.lstart = opts.lstart
  lk.lend = opts.lend

  async.await(1, vim.schedule)

  local ok, url = pcall(opts.router, lk, true)
  -- logger:debug(
  --   "|link| ok:%s, url:%s, router:%s",
  --   vim.inspect(ok),
  --   vim.inspect(url),
  --   vim.inspect(opts.router)
  -- )
  log.ensure(
    ok and not types.str_empty(url),
    string.format(
      "fatal: failed to generate permanent url from remote (%s): %s",
      vim.inspect(lk.remote_url),
      vim.inspect(url)
    )
  )

  -- The action is user code: a custom clipboard, a `vim.ui.open()` wrapper, an
  -- OSC 52 call. Raising from it is an ordinary mistake, but this function runs
  -- inside a task that nobody waits on, so a bare call loses the error
  -- completely -- no message, and `v:errmsg` stays empty. Catch it and report
  -- it the same way the router is reported.
  if opts.action then
    local action = opts.action --[[@as fun(url:string):any]]
    local action_ok, action_err = pcall(action, url --[[@as string]])
    if not action_ok then
      log.err(
        string.format("fatal: failed to run the action on url: %s", _error_message(action_err))
      )
    end
  end

  if highlight_target then
    local start = highlight_target.start
    local finish = highlight_target.finish
    local duration = highlight_target.duration
    vim.schedule(function()
      -- Drawing happens after the link is done, so a failure here cannot fail
      -- the link itself. Left alone it escapes the scheduled callback, which
      -- lands in `v:errmsg` and on stderr as a raw traceback; report it like
      -- every other failure instead.
      local shown, show_err = pcall(highlight.show, bufnr, start, finish, duration)
      if not shown then
        log.err(
          string.format("fatal: failed to highlight the linked lines: %s", _error_message(show_err))
        )
      end
    end)
  end

  local message = confs.message
  if type(opts.message) == "boolean" then
    message = opts.message
  end
  log.debug(
    string.format(
      "|_link| message:%s, opts:%s, confs:%s",
      vim.inspect(message),
      vim.inspect(opts),
      vim.inspect(confs)
    )
  )
  local warn_on_file_change = confs.warn_on_file_change
  if type(opts.warn_on_file_change) == "boolean" then
    warn_on_file_change = opts.warn_on_file_change
  end
  if lk.file_changed and warn_on_file_change then
    -- `log.warn`/`log.info` hand the message to `vim.notify`, which renders it
    -- verbatim. A file name that needed uri-encoding arrives here as
    -- `some%20dir/a%20b.lua`, so escaping the `%` again printed a link that
    -- disagreed with the one in the clipboard.
    log.warn(
      string.format(
        "line numbers can be wrong, %s has changed since %s",
        lk.file,
        string.sub(lk.rev, 1, 8)
      )
    )
  end

  if message then
    ---@diagnostic disable-next-line: need-check-nil
    log.info(url --[[@as string]])
  end

  return url
end

--- @param opts {action:gitlinker.Action?,router:gitlinker.Router,lstart:integer,lend:integer,message:boolean?,warn_on_file_change:boolean?,highlight_duration:integer?,remote:string?,file:string?,rev:string?}
--- @return string?
local _void_link = function(opts)
  return async.run(_link, opts)
end

--- Split the command line arguments into its `key=value` parameters.
---
--- The arguments arrive exactly as the user typed them, quotes included, so the
--- split cannot be a plain `vim.split(" ")`: `file=some dir/a b.lua` is one
--- value with spaces in it, and `:GitLink file="some dir/a b.lua"` is the same
--- value quoted. Both forms are accepted; a backslash escapes the character
--- that follows it, inside and outside quotes, so a value may also contain a
--- literal `"`.
---
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

  -- A word is a run of characters split only by unescaped, unquoted blanks.
  local words = {}
  local word = {}
  local quote = nil
  local i = 1
  local len = string.len(args)
  while i <= len do
    local c = string.sub(args, i, i)
    if c == "\\" and i < len then
      i = i + 1
      table.insert(word, string.sub(args, i, i))
    elseif quote then
      if c == quote then
        quote = nil
      else
        table.insert(word, c)
      end
    elseif c == '"' or c == "'" then
      quote = c
    elseif c == " " or c == "\t" then
      if #word > 0 then
        table.insert(words, table.concat(word))
        word = {}
      end
    else
      table.insert(word, c)
    end
    i = i + 1
  end
  if #word > 0 then
    table.insert(words, table.concat(word))
  end

  for _, a in ipairs(words) do
    if string.len(a) > 0 then
      if vim.startswith(a, "remote=") then
        remote = a:sub(8)
      elseif vim.startswith(a, "file=") then
        file = a:sub(6)
      elseif vim.startswith(a, "rev=") then
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
  vim.g.loaded_gitlinker = 1
  local confs = configs.setup(opts)

  -- logger
  log.setup({
    level = confs.debug and vim.log.levels.DEBUG or vim.log.levels.INFO,
    use_console = confs.console_log,
    use_file = confs.file_log,
  })

  -- command
  vim.api.nvim_create_user_command(confs.command.name, function(command_opts)
    local args = (type(command_opts.args) == "string" and string.len(command_opts.args) > 0)
        and vim.trim(command_opts.args)
      or nil

    -- A range typed on the command line wins over the cursor line, otherwise
    -- `:1,3GitLink` run from line 15 would link lines 1 to 15. `range` is what
    -- separates "no range" from "a range the cursor happens to sit in": Vim
    -- leaves it at 0 when the command was given none, and only then do
    -- `line1`/`line2` fall back to the cursor line.
    local lstart, lend
    if command_opts.range > 0 then
      lstart, lend = command_opts.line1, command_opts.line2
    else
      -- Visual mode reaches here without a range when it is mapped through
      -- `<cmd>`, so fall back to the selection the marks still describe.
      local r = range.make_range()
      lstart = math.min(r.lstart, r.lend)
      lend = math.max(r.lstart, r.lend)
    end
    local parsed = _parse_args(args)

    local action = nil
    if command_opts.bang then
      action = require("gitlinker.actions").open
    else
      -- Prefer using user provided clipboard action, if exists.
      if vim.is_callable(confs.clipboard_override) then
        action = confs.clipboard_override
      else
        action = require("gitlinker.actions").clipboard
      end
    end

    _void_link({
      action = action,
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
end

--- Copy the options before filling in the defaults: a keymap closure hands the
--- same table to every press, so writing the defaults into the caller's table
--- would make the second press reuse the line range resolved by the first one.
---
--- @param opts {router_type:string?,router:gitlinker.Router?,action:gitlinker.Action?,lstart:integer?,lend:integer?,message:boolean?,warn_on_file_change:boolean?,highlight_duration:integer?,remote:string?,file:string?,rev:string?}?
local function link(opts)
  opts = vim.deepcopy(opts or {})

  opts.router_type = types.str_empty(opts.router_type) and "browse" or opts.router_type
  opts.action = vim.is_callable(opts.action) and opts.action
    or require("gitlinker.actions").clipboard
  opts.router = vim.is_callable(opts.router) and opts.router
    or function(lk)
      return _router(opts.router_type, lk)
    end
  opts.lstart, opts.lend = _normalize_range(opts.lstart, opts.lend)

  _void_link({
    action = opts.action,
    router = opts.router,
    lstart = opts.lstart,
    lend = opts.lend,
    message = opts.message,
    warn_on_file_change = opts.warn_on_file_change,
    highlight_duration = opts.highlight_duration,
    remote = opts.remote,
    file = opts.file,
    rev = opts.rev,
  })
end

local M = {
  _url_template_engine = _url_template_engine,
  _worker = _worker,
  _void_link = _void_link,
  _router = _router,
  _browse = _browse,
  _blame = _blame,
  _parse_args = _parse_args,
  _normalize_range = _normalize_range,

  setup = setup,
  link = link,
}

return M
