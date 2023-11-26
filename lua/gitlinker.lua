local range = require("gitlinker.range")
local LogLevels = require("gitlinker.logger").LogLevels
local logger = require("gitlinker.logger")
local linker = require("gitlinker.linker")
local highlight = require("gitlinker.highlight")
local deprecation = require("gitlinker.deprecation")
local utils = require("gitlinker.utils")

--- @alias gitlinker.Options table<any, any>
--- @type gitlinker.Options
local Defaults = {
  -- print permanent url in command line
  message = true,

  -- highlight the linked region
  highlight_duration = 500,

  -- user command
  command = {
    -- to copy link to clipboard, use: 'GitLink'
    -- to open link in browser, use bang: 'GitLink!'
    -- to use blame router, use: 'GitLink blame'
    -- to use browse router, use: 'GitLink browse' (which is the default router)
    name = "GitLink",
    desc = "Generate git permanent link",
  },

  -- router bindings
  router = {
    browse = {
      -- example: https://github.com/linrongbin16/gitlinker.nvim/blob/9679445c7a24783d27063cd65f525f02def5f128/lua/gitlinker.lua#L3-L4
      ["^github%.com"] = "https://github.com/"
        .. "{_A.USER}/"
        .. "{_A.REPO}/blob/"
        .. "{_A.REV}/"
        .. "{_A.FILE}"
        .. "{(string.len(_A.FILE) >= 3 and _A.FILE:sub(#_A.FILE-2) == '.md') and '?plain=1' or ''}" -- '?plain=1'
        .. "#L{_A.LSTART}"
        .. "{(_A.LEND > _A.LSTART and ('-L' .. _A.LEND) or '')}",
      -- example: https://gitlab.com/linrongbin16/gitlinker.nvim/blob/9679445c7a24783d27063cd65f525f02def5f128/lua/gitlinker.lua#L3-L4
      ["^gitlab%.com"] = "https://gitlab.com/"
        .. "{_A.USER}/"
        .. "{_A.REPO}/blob/"
        .. "{_A.REV}/"
        .. "{_A.FILE}"
        .. "#L{_A.LSTART}"
        .. "{(_A.LEND > _A.LSTART and ('-L' .. _A.LEND) or '')}",
      -- example: https://bitbucket.org/linrongbin16/gitlinker.nvim/src/9679445c7a24783d27063cd65f525f02def5f128/lua/gitlinker.lua#L3-L4
      ["^bitbucket%.org"] = "https://bitbucket.org/"
        .. "{_A.USER}/"
        .. "{_A.REPO}/src/"
        .. "{_A.REV}/"
        .. "{_A.FILE}"
        .. "#lines-{_A.LSTART}"
        .. "{(_A.LEND > _A.LSTART and (':' .. _A.LEND) or '')}",
      -- example: https://codeberg.org/linrongbin16/gitlinker.nvim/src/commit/a570f22ff833447ee0c58268b3bae4f7197a8ad8/LICENSE#L5-L6
      ["^codeberg%.org"] = "https://codeberg.org/"
        .. "{_A.USER}/"
        .. "{_A.REPO}/src/commit/"
        .. "{_A.REV}/"
        .. "{_A.FILE}"
        .. "{(string.len(_A.FILE) >= 3 and _A.FILE:sub(#_A.FILE-2) == '.md') and '?display=source' or ''}" -- '?display=source'
        .. "#L{_A.LSTART}"
        .. "{(_A.LEND > _A.LSTART and ('-L' .. _A.LEND) or '')}",
      -- example:
      -- main repo: https://git.samba.org/?p=samba.git;a=blob;f=wscript;hb=83e8971c0f1c1db8c3574f83107190ac1ac23db0#l6
      -- dev repo: https://git.samba.org/?p=bbaumbach/samba.git;a=blob;f=wscript;hb=8de348e9d025d336a7985a9025fe08b7096c0394#l7
      ["^git%.samba%.org"] = "https://git.samba.org/?p="
        .. "{string.len(_A.USER) > 0 and (_A.USER .. '/') or ''}" -- 'p=samba.git;' or 'p=bbaumbach/samba.git;'
        .. "{_A.REPO .. '.git'};a=blob;"
        .. "f={_A.FILE};"
        .. "hb={_A.REV}"
        .. "#l{_A.LSTART}",
    },
    blame = {
      -- example: https://github.com/linrongbin16/gitlinker.nvim/blame/9679445c7a24783d27063cd65f525f02def5f128/lua/gitlinker.lua#L3-L4
      ["^github%.com"] = "https://github.com/"
        .. "{_A.USER}/"
        .. "{_A.REPO}/blame/"
        .. "{_A.REV}/"
        .. "{_A.FILE}"
        .. "{(string.len(_A.FILE) >= 3 and _A.FILE:sub(#_A.FILE-2) == '.md') and '?plain=1' or ''}"
        .. "#L{_A.LSTART}"
        .. "{(_A.LEND > _A.LSTART and ('-L' .. _A.LEND) or '')}",
      -- example: https://gitlab.com/linrongbin16/gitlinker.nvim/blame/9679445c7a24783d27063cd65f525f02def5f128/lua/gitlinker.lua#L3-L4
      ["^gitlab%.com"] = "https://gitlab.com/"
        .. "{_A.USER}/"
        .. "{_A.REPO}/blame/"
        .. "{_A.REV}/"
        .. "{_A.FILE}"
        .. "#L{_A.LSTART}"
        .. "{(_A.LEND > _A.LSTART and ('-L' .. _A.LEND) or '')}",
      -- example: https://bitbucket.org/linrongbin16/gitlinker.nvim/annotate/9679445c7a24783d27063cd65f525f02def5f128/lua/gitlinker.lua#L3-L4
      ["^bitbucket%.org"] = "https://bitbucket.org/"
        .. "{_A.USER}/"
        .. "{_A.REPO}/annotate/"
        .. "{_A.REV}/"
        .. "{_A.FILE}"
        .. "#lines-{_A.LSTART}"
        .. "{(_A.LEND > _A.LSTART and (':' .. _A.LEND) or '')}",
      -- example: https://codeberg.org/linrongbin16/gitlinker.nvim/blame/commit/a570f22ff833447ee0c58268b3bae4f7197a8ad8/LICENSE#L5-L6
      ["^codeberg%.org"] = "https://codeberg.org/"
        .. "{_A.USER}/"
        .. "{_A.REPO}/blame/commit/"
        .. "{_A.REV}/"
        .. "{_A.FILE}"
        .. "#L{_A.LSTART}"
        .. "{(_A.LEND > _A.LSTART and ('-L' .. _A.LEND) or '')}",
    },
  },

  -- enable debug
  debug = false,

  -- write logs to console(command line)
  console_log = true,

  -- write logs to file
  file_log = false,
}

--- @type gitlinker.Options
local Configs = {}

--- @param opts gitlinker.Options
local function deprecated_notification(opts)
  if type(opts) == "table" and opts.pattern_rules ~= nil then
    deprecation.notify(
      "'pattern_rules' option is deprecated! please migrate to latest configs."
    )
  end
  if type(opts) == "table" and opts.override_rules ~= nil then
    deprecation.notify(
      "'override_rules' option is deprecated! please migrate to latest configs."
    )
  end
  if type(opts) == "table" and opts.custom_rules ~= nil then
    deprecation.notify(
      "'custom_rules' option is deprecated! please migrate to latest configs."
    )
  end
end

--- @param lk gitlinker.Linker
--- @param template string
--- @return string
local function _url_template_engine(lk, template)
  local OPEN_BRACE = "{"
  local CLOSE_BRACE = "}"
  if type(template) ~= "string" or string.len(template) == 0 then
    return template
  end

  --- @alias gitlinker.UrlTemplateExpr {plain:boolean,body:string}
  --- @type gitlinker.UrlTemplateExpr[]
  local exprs = {}

  local i = 1
  local n = string.len(template)
  while i <= n do
    local open_pos = utils.string_find(template, OPEN_BRACE, i)
    if not open_pos then
      table.insert(exprs, { plain = true, body = string.sub(template, i) })
      break
    end
    table.insert(
      exprs,
      { plain = true, body = string.sub(template, i, open_pos - 1) }
    )
    local close_pos = utils.string_find(
      template,
      CLOSE_BRACE,
      open_pos + string.len(OPEN_BRACE)
    )
    assert(
      type(close_pos) == "number" and close_pos > open_pos,
      string.format(
        "failed to evaluate url template(%s) at pos %d",
        vim.inspect(template),
        open_pos + string.len(OPEN_BRACE)
      )
    )
    table.insert(exprs, {
      plain = false,
      body = string.sub(
        template,
        open_pos + string.len(OPEN_BRACE),
        close_pos - 1
      ),
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
        PROTOCOL = lk.protocol,
        HOST = lk.host,
        USER = lk.user,
        REPO = utils.string_endswith(lk.repo, ".git")
            and lk.repo:sub(1, #lk.repo - 4)
          or lk.repo,
        REV = lk.rev,
        FILE = lk.file,
        LSTART = lk.lstart,
        LEND = (type(lk.lend) == "number" and lk.lend > lk.lstart) and lk.lend
          or lk.lstart,
      })
      -- logger.debug(
      --   "|_url_template_engine| exp:%s, lk:%s, evaluated:%s",
      --   vim.inspect(exp.body),
      --   vim.inspect(lk),
      --   vim.inspect(evaluated)
      -- )
      table.insert(results, evaluated)
    end
  end

  return table.concat(results, "")
end

--- @param lk gitlinker.Linker
--- @return string
local function _make_resolved_remote_url(lk)
  local resolved_remote_url =
    string.format("%s%s%s%s", lk.protocol, lk.host, lk.host_delimiter, lk.user)
  if type(lk.repo) == "string" and string.len(lk.repo) > 0 then
    resolved_remote_url = string.format("%s/%s", resolved_remote_url, lk.repo)
  end
  return resolved_remote_url
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
    assert(
      false,
      string.format(
        "unsupported router %s on pattern %s",
        vim.inspect(r),
        vim.inspect(p)
      )
    )
    return nil
  end
end

--- @alias gitlinker.Router fun(lk:gitlinker.Linker):string
--- @param router_type string
--- @param lk gitlinker.Linker
--- @return string?
local function _router(router_type, lk)
  assert(
    type(Configs._routers[router_type]) == "table",
    string.format("unknown router type %s!", vim.inspect(router_type))
  )
  assert(
    type(Configs._routers[router_type].list_routers) == "table",
    string.format(
      "invalid router type %s! 'list_routers' missing.",
      vim.inspect(router_type)
    )
  )
  assert(
    type(Configs._routers[router_type].map_routers) == "table",
    string.format(
      "invalid router type %s! 'map_routers' missing.",
      vim.inspect(router_type)
    )
  )

  for i, tuple in ipairs(Configs._routers[router_type].list_routers) do
    if type(i) == "number" and type(tuple) == "table" and #tuple == 2 then
      local pattern = tuple[1]
      local route = tuple[2]
      local resolved_remote_url = _make_resolved_remote_url(lk)
      logger.debug(
        "|gitlinker._router| list i:%d, pattern_route_tuple:%s, match host:%s(%s), remote_url:%s(%s), resolved_remote_url:%s(%s)",
        vim.inspect(i),
        vim.inspect(tuple),
        vim.inspect(string.match(lk.host, pattern)),
        vim.inspect(lk.host),
        vim.inspect(string.match(lk.remote_url, pattern)),
        vim.inspect(lk.remote_url),
        vim.inspect(string.match(resolved_remote_url, pattern)),
        vim.inspect(resolved_remote_url)
      )
      if
        string.match(lk.host, pattern)
        or string.match(lk.remote_url, pattern)
        or string.match(resolved_remote_url, pattern)
      then
        logger.debug(
          "|browse| match-1 router:%s with pattern:%s",
          vim.inspect(route),
          vim.inspect(pattern)
        )
        return _worker(lk, pattern, route)
      end
    end
  end
  for pattern, route in pairs(Configs._routers[router_type].map_routers) do
    if
      type(pattern) == "string"
      and string.len(pattern) > 0
      and (type(route) == "string" or type(route) == "function")
    then
      local resolved_remote_url = _make_resolved_remote_url(lk)
      logger.debug(
        "|gitlinker._router| table pattern:%s, match host:%s, remote_url:%s, resolved_remote_url:%s",
        vim.inspect(pattern),
        vim.inspect(lk.host),
        vim.inspect(lk.remote_url),
        vim.inspect(resolved_remote_url)
      )
      if
        string.match(lk.host, pattern)
        or string.match(lk.remote_url, pattern)
        or string.match(resolved_remote_url, pattern)
      then
        logger.debug(
          "|browse| match-2 router:%s with pattern:%s",
          vim.inspect(route),
          vim.inspect(pattern)
        )
        return _worker(lk, pattern, route)
      end
    end
  end
  assert(
    false,
    string.format(
      "%s not support, please bind it in 'router'!",
      vim.inspect(lk.host)
    )
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

--- @param opts {action:gitlinker.Action,router:gitlinker.Router,lstart:integer,lend:integer}
--- @return string?
local function link(opts)
  -- logger.debug("[link] merged opts: %s", vim.inspect(opts))

  local lk = linker.make_linker()
  if not lk then
    return nil
  end
  lk.lstart = opts.lstart
  lk.lend = opts.lend

  local ok, url = pcall(opts.router, lk, true)
  logger.debug(
    "|link| ok:%s, url:%s, router:%s",
    vim.inspect(ok),
    vim.inspect(url),
    vim.inspect(opts.router)
  )
  logger.ensure(
    ok and type(url) == "string" and string.len(url) > 0,
    "fatal: failed to generate permanent url from remote url (%s): %s",
    vim.inspect(lk.remote_url),
    vim.inspect(url)
  )

  if opts.action then
    opts.action(url --[[@as string]])
  end

  if Configs.highlight_duration > 0 then
    highlight.show({ lstart = lk.lstart, lend = lk.lend })
    vim.defer_fn(highlight.clear, Configs.highlight_duration)
  end

  if Configs.message then
    local msg = lk.file_changed
        and string.format("%s (lines can be wrong due to file change)", url)
      or url
    logger.info(msg)
  end

  return url
end

--- @param opts gitlinker.Options
--- @return table<string, {list_routers:table,map_routers:table}>
local function _merge_routers(opts)
  local result = {}
  -- default routers
  -- default_router_type: browse, blame, etc
  for default_router_type, default_router_bindings in pairs(Defaults.router) do
    if result[default_router_type] == nil then
      result[default_router_type] = {}
      result[default_router_type].list_routers = {}
      result[default_router_type].map_routers = {}
    end
    -- list
    for i, tuple in ipairs(default_router_bindings) do
      if type(i) == "number" and type(tuple) == "table" and #tuple == 2 then
        table.insert(result[default_router_type].list_routers, tuple)
      end
    end
    -- map
    for pattern, route in pairs(default_router_bindings) do
      if result[default_router_type].map_routers == nil then
        result[default_router_type].map_routers = {}
      end
      if
        type(pattern) == "string"
        and string.len(pattern) > 0
        and (type(route) == "string" or type(route) == "function")
      then
        result[default_router_type].map_routers[pattern] = route
      end
    end
  end
  if type(opts.router) == "table" then
    -- user_router_type: browse, blame, etc
    for user_router_type, user_router_bindings in pairs(opts.router) do
      if result[user_router_type] == nil then
        result[user_router_type] = {}
        result[user_router_type].list_routers = {}
        result[user_router_type].map_routers = {}
      end
      -- list
      for i, tuple in ipairs(user_router_bindings) do
        if type(i) == "number" and type(tuple) == "table" and #tuple == 2 then
          -- prepend to head for higher priority
          table.insert(result[user_router_type].list_routers, 1, tuple)
        end
      end
      -- map
      for pattern, route in pairs(user_router_bindings) do
        if result[user_router_type].map_routers == nil then
          result[user_router_type].map_routers = {}
        end
        if
          type(pattern) == "string"
          and string.len(pattern) > 0
          and (type(route) == "string" or type(route) == "function")
        then
          -- override default routers
          result[user_router_type].map_routers[pattern] = route
        end
      end
    end
  end
  -- logger.debug("|gitlinker._merge_routers| result:%s", vim.inspect(result))
  return result
end

--- @param opts gitlinker.Options?
local function setup(opts)
  local merged_routers = _merge_routers(opts or {})
  Configs = vim.tbl_deep_extend("force", vim.deepcopy(Defaults), opts or {})
  Configs._routers = merged_routers

  -- logger
  logger.setup({
    level = Configs.debug and LogLevels.DEBUG or LogLevels.INFO,
    console_log = Configs.console_log,
    file_log = Configs.file_log,
  })

  logger.debug("|gitlinker.setup| Configs:%s", vim.inspect(Configs))

  -- command
  vim.api.nvim_create_user_command(Configs.command.name, function(command_opts)
    local r = range.make_range()
    local parsed_args = (
      type(command_opts.args) == "string"
      and string.len(command_opts.args) > 0
    )
        and vim.trim(command_opts.args)
      or nil
    logger.debug(
      "command opts:%s, parsed:%s, range:%s",
      vim.inspect(command_opts),
      vim.inspect(parsed_args),
      vim.inspect(r)
    )
    local lstart =
      math.min(r.lstart, r.lend, command_opts.line1, command_opts.line2)
    local lend =
      math.max(r.lstart, r.lend, command_opts.line1, command_opts.line2)
    local router_type = type(parsed_args) == "string"
        and string.len(parsed_args) > 0
        and parsed_args
      or "browse"
    local router = function(lk)
      return _router(router_type, lk)
    end
    local action = require("gitlinker.actions").clipboard
    if command_opts.bang then
      action = require("gitlinker.actions").system
    end
    link({ action = action, router = router, lstart = lstart, lend = lend })
  end, {
    nargs = "*",
    range = true,
    bang = true,
    desc = Configs.command.desc,
  })

  if type(Configs.mapping) == "table" then
    deprecation.notify(
      "'mapping' option is deprecated! please migrate to 'GitLink' command."
    )
  end

  -- Configure highlight group
  if Configs.highlight_duration > 0 then
    local hl_group = "NvimGitLinkerHighlightTextObject"
    if not highlight.hl_group_exists(hl_group) then
      vim.api.nvim_set_hl(0, hl_group, { link = "Search" })
    end
  end

  -- logger.debug("|setup| Configs:%s", vim.inspect(Configs))

  deprecated_notification(Configs)
end

local M = {
  setup = setup,
  link = link,
  _make_resolved_remote_url = _make_resolved_remote_url,
  _worker = _worker,
  _browse = _browse,
  _blame = _blame,
  _merge_routers = _merge_routers,
}

return M
