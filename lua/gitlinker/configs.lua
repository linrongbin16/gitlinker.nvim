local M = {}

-- NOTE: Bitbucket Cloud serves ssh traffic on a dedicated host,
-- 'ssh.bitbucket.org' (and 'altssh.bitbucket.org' for the port 443 alternative),
-- while the website is still served on 'bitbucket.org'. Since Git over ssh is
-- what most remotes use, all of them should be bound to the same website:
-- https://community.atlassian.com/forums/discussion/3234032

-- example: https://bitbucket.org/gitlinkernvim/gitlinker.nvim/src/dbf3922382576391fbe50b36c55066c1768b08b6/.gitignore#lines-9:14
local BITBUCKET_BROWSE = "https://bitbucket.org/"
  .. "{_A.ORG}/"
  .. "{_A.REPO}/src/"
  .. "{_A.REV}/"
  .. "{_A.FILE}"
  .. "#lines-{_A.LSTART}"
  .. "{(_A.LEND > _A.LSTART and (':' .. _A.LEND) or '')}"

-- example: https://bitbucket.org/gitlinkernvim/gitlinker.nvim/annotate/dbf3922382576391fbe50b36c55066c1768b08b6/.gitignore#lines-9:14
local BITBUCKET_BLAME = "https://bitbucket.org/"
  .. "{_A.ORG}/"
  .. "{_A.REPO}/annotate/"
  .. "{_A.REV}/"
  .. "{_A.FILE}"
  .. "#lines-{_A.LSTART}"
  .. "{(_A.LEND > _A.LSTART and (':' .. _A.LEND) or '')}"

-- example: https://bitbucket.org/gitlinkernvim/gitlinker.nvim/src/master/.gitignore#lines-9:14
local BITBUCKET_DEFAULT_BRANCH = "https://bitbucket.org/"
  .. "{_A.ORG}/"
  .. "{_A.REPO}/src/"
  .. "{_A.DEFAULT_BRANCH}/"
  .. "{_A.FILE}"
  .. "#lines-{_A.LSTART}"
  .. "{(_A.LEND > _A.LSTART and (':' .. _A.LEND) or '')}"

-- example: https://bitbucket.org/gitlinkernvim/gitlinker.nvim/src/feat-dev/.gitignore#lines-9:14
local BITBUCKET_CURRENT_BRANCH = "https://bitbucket.org/"
  .. "{_A.ORG}/"
  .. "{_A.REPO}/src/"
  .. "{_A.CURRENT_BRANCH}/"
  .. "{_A.FILE}"
  .. "#lines-{_A.LSTART}"
  .. "{(_A.LEND > _A.LSTART and (':' .. _A.LEND) or '')}"

local Defaults = {
  -- print permanent url in command line
  message = true,

  -- warn when the file has changed since the commit the url points at, i.e.
  -- when its line numbers no longer describe the file.
  warn_on_file_change = true,

  -- highlight the linked region
  highlight_duration = 500,

  -- user command
  command = {
    name = "GitLink",
    desc = "Generate git permanent link",
  },

  -- router bindings
  router = {
    browse = {
      -- example: https://github.com/linrongbin16/gitlinker.nvim/blob/9679445c7a24783d27063cd65f525f02def5f128/lua/gitlinker.lua#L3-L4
      ["^github%.com"] = "https://github.com/"
        .. "{_A.ORG}/"
        .. "{_A.REPO}/blob/"
        .. "{_A.REV}/"
        .. "{_A.FILE}?plain=1" -- '?plain=1'
        .. "#L{_A.LSTART}"
        .. "{(_A.LEND > _A.LSTART and ('-L' .. _A.LEND) or '')}",
      -- example: https://gitlab.com/linrongbin16/test/blob/e1c498a4bae9af6e61a2f37e7ae622b2cc629319/test.lua#L3-L5
      ["^gitlab%.com"] = "https://gitlab.com/"
        .. "{_A.ORG}/"
        .. "{_A.REPO}/blob/"
        .. "{_A.REV}/"
        .. "{_A.FILE}"
        .. "#L{_A.LSTART}"
        .. "{(_A.LEND > _A.LSTART and ('-L' .. _A.LEND) or '')}",
      -- example: https://bitbucket.org/gitlinkernvim/gitlinker.nvim/src/dbf3922382576391fbe50b36c55066c1768b08b6/.gitignore#lines-9:14
      ["^bitbucket%.org"] = BITBUCKET_BROWSE,
      ["^ssh%.bitbucket%.org"] = BITBUCKET_BROWSE,
      ["^altssh%.bitbucket%.org"] = BITBUCKET_BROWSE,
      -- example: https://codeberg.org/linrongbin16/gitlinker.nvim/src/commit/a570f22ff833447ee0c58268b3bae4f7197a8ad8/LICENSE#L4-L7
      ["^codeberg%.org"] = "https://codeberg.org/"
        .. "{_A.ORG}/"
        .. "{_A.REPO}/src/commit/"
        .. "{_A.REV}/"
        .. "{_A.FILE}?display=source" -- '?display=source'
        .. "#L{_A.LSTART}"
        .. "{(_A.LEND > _A.LSTART and ('-L' .. _A.LEND) or '')}",
      -- example:
      -- main repo: https://git.samba.org/?p=samba.git;a=blob;f=wscript;hb=83e8971c0f1c1db8c3574f83107190ac1ac23db0#l6
      -- user repo: https://git.samba.org/?p=bbaumbach/samba.git;a=blob;f=wscript;hb=8de348e9d025d336a7985a9025fe08b7096c0394#l7
      ["^git%.samba%.org"] = "https://git.samba.org/?p="
        .. "{string.len(_A.ORG) > 0 and (_A.ORG .. '/') or ''}" -- 'p=samba.git;' or 'p=bbaumbach/samba.git;'
        .. "{_A.REPO .. '.git'};a=blob;"
        .. "f={_A.FILE};"
        .. "hb={_A.REV}"
        .. "#l{_A.LSTART}",
    },
    blame = {
      -- example: https://github.com/linrongbin16/gitlinker.nvim/blame/9679445c7a24783d27063cd65f525f02def5f128/lua/gitlinker.lua#L3-L7
      ["^github%.com"] = "https://github.com/"
        .. "{_A.ORG}/"
        .. "{_A.REPO}/blame/"
        .. "{_A.REV}/"
        .. "{_A.FILE}?plain=1" -- '?plain=1'
        .. "#L{_A.LSTART}"
        .. "{(_A.LEND > _A.LSTART and ('-L' .. _A.LEND) or '')}",
      -- example: https://gitlab.com/linrongbin16/test/blame/e1c498a4bae9af6e61a2f37e7ae622b2cc629319/test.lua#L4-8
      ["^gitlab%.com"] = "https://gitlab.com/"
        .. "{_A.ORG}/"
        .. "{_A.REPO}/blame/"
        .. "{_A.REV}/"
        .. "{_A.FILE}"
        .. "#L{_A.LSTART}"
        .. "{(_A.LEND > _A.LSTART and ('-L' .. _A.LEND) or '')}",
      -- example: https://bitbucket.org/gitlinkernvim/gitlinker.nvim/annotate/dbf3922382576391fbe50b36c55066c1768b08b6/.gitignore#lines-9:14
      ["^bitbucket%.org"] = BITBUCKET_BLAME,
      ["^ssh%.bitbucket%.org"] = BITBUCKET_BLAME,
      ["^altssh%.bitbucket%.org"] = BITBUCKET_BLAME,
      -- example: https://codeberg.org/linrongbin16/gitlinker.nvim/blame/commit/a570f22ff833447ee0c58268b3bae4f7197a8ad8/LICENSE#L4-L7
      ["^codeberg%.org"] = "https://codeberg.org/"
        .. "{_A.ORG}/"
        .. "{_A.REPO}/blame/commit/"
        .. "{_A.REV}/"
        .. "{_A.FILE}?display=source" -- '?display=source'
        .. "#L{_A.LSTART}"
        .. "{(_A.LEND > _A.LSTART and ('-L' .. _A.LEND) or '')}",
    },
    default_branch = {
      -- example: https://github.com/linrongbin16/gitlinker.nvim/blob/master/lua/gitlinker.lua#L3-L4
      ["^github%.com"] = "https://github.com/"
        .. "{_A.ORG}/"
        .. "{_A.REPO}/blob/"
        .. "{_A.DEFAULT_BRANCH}/"
        .. "{_A.FILE}?plain=1" -- '?plain=1'
        .. "#L{_A.LSTART}"
        .. "{(_A.LEND > _A.LSTART and ('-L' .. _A.LEND) or '')}",
      -- example: https://gitlab.com/linrongbin16/test/blob/main/test.lua#L3-L4
      ["^gitlab%.com"] = "https://gitlab.com/"
        .. "{_A.ORG}/"
        .. "{_A.REPO}/blob/"
        .. "{_A.DEFAULT_BRANCH}/"
        .. "{_A.FILE}"
        .. "#L{_A.LSTART}"
        .. "{(_A.LEND > _A.LSTART and ('-L' .. _A.LEND) or '')}",
      -- example: https://bitbucket.org/gitlinkernvim/gitlinker.nvim/src/master/.gitignore#lines-9:14
      ["^bitbucket%.org"] = BITBUCKET_DEFAULT_BRANCH,
      ["^ssh%.bitbucket%.org"] = BITBUCKET_DEFAULT_BRANCH,
      ["^altssh%.bitbucket%.org"] = BITBUCKET_DEFAULT_BRANCH,
      -- example: https://codeberg.org/linrongbin16/gitlinker.nvim/src/branch/main/LICENSE#L4-L6
      ["^codeberg%.org"] = "https://codeberg.org/"
        .. "{_A.ORG}/"
        .. "{_A.REPO}/src/branch/"
        .. "{_A.DEFAULT_BRANCH}/"
        .. "{_A.FILE}?display=source" -- '?display=source'
        .. "#L{_A.LSTART}"
        .. "{(_A.LEND > _A.LSTART and ('-L' .. _A.LEND) or '')}",
      -- example:
      -- main repo: https://git.samba.org/?p=samba.git;a=blob;f=wscript#l6
      -- user repo: https://git.samba.org/?p=bbaumbach/samba.git;a=blob;f=wscript#l7
      ["^git%.samba%.org"] = "https://git.samba.org/?p="
        .. "{string.len(_A.ORG) > 0 and (_A.ORG .. '/') or ''}" -- 'p=samba.git;' or 'p=bbaumbach/samba.git;'
        .. "{_A.REPO .. '.git'};a=blob;"
        .. "f={_A.FILE}"
        .. "#l{_A.LSTART}",
    },
    current_branch = {
      -- example: https://github.com/linrongbin16/gitlinker.nvim/blob/master/lua/gitlinker.lua#L3-L4
      ["^github%.com"] = "https://github.com/"
        .. "{_A.ORG}/"
        .. "{_A.REPO}/blob/"
        .. "{_A.CURRENT_BRANCH}/"
        .. "{_A.FILE}?plain=1" -- '?plain=1'
        .. "#L{_A.LSTART}"
        .. "{(_A.LEND > _A.LSTART and ('-L' .. _A.LEND) or '')}",
      -- example: https://gitlab.com/linrongbin16/test/blob/main/test.lua#L3-L4
      ["^gitlab%.com"] = "https://gitlab.com/"
        .. "{_A.ORG}/"
        .. "{_A.REPO}/blob/"
        .. "{_A.CURRENT_BRANCH}/"
        .. "{_A.FILE}"
        .. "#L{_A.LSTART}"
        .. "{(_A.LEND > _A.LSTART and ('-L' .. _A.LEND) or '')}",
      -- example: https://bitbucket.org/gitlinkernvim/gitlinker.nvim/src/feat-dev/.gitignore#lines-9:14
      ["^bitbucket%.org"] = BITBUCKET_CURRENT_BRANCH,
      ["^ssh%.bitbucket%.org"] = BITBUCKET_CURRENT_BRANCH,
      ["^altssh%.bitbucket%.org"] = BITBUCKET_CURRENT_BRANCH,
      -- example: https://codeberg.org/linrongbin16/gitlinker.nvim/src/branch/main/LICENSE#L4-L6
      ["^codeberg%.org"] = "https://codeberg.org/"
        .. "{_A.ORG}/"
        .. "{_A.REPO}/src/branch/"
        .. "{_A.CURRENT_BRANCH}/"
        .. "{_A.FILE}?display=source" -- '?display=source'
        .. "#L{_A.LSTART}"
        .. "{(_A.LEND > _A.LSTART and ('-L' .. _A.LEND) or '')}",
      -- example:
      -- main repo: https://git.samba.org/?p=samba.git;a=blob;f=wscript#l6
      -- user repo: https://git.samba.org/?p=bbaumbach/samba.git;a=blob;f=wscript#l7
      ["^git%.samba%.org"] = "https://git.samba.org/?p="
        .. "{string.len(_A.ORG) > 0 and (_A.ORG .. '/') or ''}" -- 'p=samba.git;' or 'p=bbaumbach/samba.git;'
        .. "{_A.REPO .. '.git'};a=blob;"
        .. "f={_A.FILE}"
        .. "#l{_A.LSTART}",
    },
  },

  -- enable debug
  debug = false,

  -- write logs to console(command line)
  console_log = true,

  -- write logs to file
  file_log = false,

  -- clipboard command
  clipboard_override = false,
}

--- @type gitlinker.Options
local Configs = {}

--- Merge user provided "list" style router bindings into `result`.
---
--- A "list" binding is an ordered array of `{pattern, route}` tuples. Each
--- tuple is prepended to the head of `list_routers`, so entries added later
--- are matched (and therefore prioritized) before earlier ones.
---
--- Example:
--- ```lua
--- -- input: opts.router = {
--- --   browse = {
--- --     { "^github%.your%.host", "https://github.your.host/{_A.ORG}/{_A.REPO}/blob/{_A.REV}/{_A.FILE}" },
--- --     { "^gitlab%.your%.host", function(lk) return "https://gitlab.your.host/" .. lk.repo end },
--- --   },
--- -- }
--- -- result.browse.list_routers after this call:
--- --   { { "^gitlab%.your%.host", <function> }, { "^github%.your%.host", "https://..." } }
--- ```
---
--- @param result table<string, {list_routers:table,map_routers:table}> merged result being built
--- @param user_routers table<string, table> user `opts.router` bindings
local function _merge_user_list_routers(result, user_routers)
  for router_type, bindings in pairs(user_routers) do
    if result[router_type] == nil then
      result[router_type] = { list_routers = {}, map_routers = {} }
    end
    for i, tuple in ipairs(bindings) do
      if type(i) == "number" and type(tuple) == "table" and #tuple == 2 then
        -- prepend to head for higher priority
        table.insert(result[router_type].list_routers, 1, tuple)
      end
    end
  end
end

--- Merge default "map" style router bindings into `result` as the fallback.
---
--- A "map" binding is keyed by a host pattern and maps to a route (a string
--- template or a lua function). Only valid `string` patterns with a
--- `string`/`function` route are accepted.
---
--- Example:
--- ```lua
--- -- input: Defaults.router = {
--- --   browse = {
--- --     ["^github%.com"] = "https://github.com/{_A.ORG}/{_A.REPO}/blob/{_A.REV}/{_A.FILE}",
--- --   },
--- -- }
--- -- result.browse.map_routers after this call:
--- --   { ["^github%.com"] = "https://github.com/..." }
--- ```
---
--- @param result table<string, {list_routers:table,map_routers:table}> merged result being built
--- @param default_routers table<string, table> `Defaults.router` bindings
local function _merge_default_map_routers(result, default_routers)
  for router_type, bindings in pairs(default_routers) do
    if result[router_type] == nil then
      result[router_type] = { list_routers = {}, map_routers = {} }
    end
    for pattern, route in pairs(bindings) do
      if
        type(pattern) == "string"
        and string.len(pattern) > 0
        and (type(route) == "string" or type(route) == "function")
      then
        result[router_type].map_routers[pattern] = route
      end
    end
  end
end

--- Merge user provided "map" style router bindings into `result`, overwriting
--- default bindings that share the same pattern.
---
--- This is how a user overrides or extends a default host route.
---
--- Example:
--- ```lua
--- -- input: opts.router = {
--- --   browse = {
--- --     ["^github%.com"] = "https://my-proxy.example.com/{_A.ORG}/{_A.REPO}/blob/{_A.REV}/{_A.FILE}",
--- --   },
--- -- }
--- -- result.browse.map_routers after this call: the "^github%.com" default
--- --   route is replaced by the user's proxy route.
--- ```
---
--- @param result table<string, {list_routers:table,map_routers:table}> merged result being built
--- @param user_routers table<string, table> user `opts.router` bindings
local function _merge_user_map_routers(result, user_routers)
  for router_type, bindings in pairs(user_routers) do
    if result[router_type] == nil then
      result[router_type] = { list_routers = {}, map_routers = {} }
    end
    for pattern, route in pairs(bindings) do
      if
        type(pattern) == "string"
        and string.len(pattern) > 0
        and (type(route) == "string" or type(route) == "function")
      then
        -- override default routers
        result[router_type].map_routers[pattern] = route
      end
    end
  end
end

--- Merge default (`Defaults.router`) and user (`opts.router`) router bindings
--- into a single lookup structure.
---
--- The result is keyed by router type (`browse`, `blame`, `default_branch`, ...)
--- and each entry holds:
--- - `list_routers`: an ordered array of `{pattern, route}` tuples, matched first.
--- - `map_routers`: a `pattern -> route` table, matched as a fallback.
---
--- Merge order and priority (higher first):
--- 1. user list bindings — prepended to `list_routers`.
--- 2. default map bindings — the built-in fallback.
--- 3. user map bindings — overwrite the defaults.
---
--- Example:
--- ```lua
--- -- input opts.router:
--- -- {
--- --   browse = {
--- --     { "^github%.your%.host", function(lk) ... end },      -- list tuple
--- --     ["^github%.com"] = "https://my-proxy.example.com/...", -- map entry
--- --   },
--- -- }
--- -- output shape:
--- -- {
--- --   browse = {
--- --     list_routers = { { "^github%.your%.host", <function> } },
--- --     map_routers = {
--- --       ["^github%.com"] = "https://my-proxy.example.com/...",
--- --       ["^gitlab%.com"] = "https://gitlab.com/...", -- untouched default
--- --     },
--- --   },
--- --   blame = { list_routers = {}, map_routers = { ... } },
--- --   default_branch = { list_routers = {}, map_routers = { ... } },
--- -- }
--- ```
---
--- @param opts gitlinker.Options
--- @return table<string, {list_routers:table,map_routers:table}>
M._merge_routers = function(opts)
  local result = {}

  local user_routers = type(opts.router) == "table" and opts.router or {}

  _merge_user_list_routers(result, user_routers)
  _merge_default_map_routers(result, Defaults.router)
  _merge_user_map_routers(result, user_routers)

  -- logger.debug("|gitlinker._merge_routers| result:%s", vim.inspect(result))
  return result
end

--- @alias gitlinker.Options table<string, any>
--- @param opts gitlinker.Options?
--- @return gitlinker.Options
M.setup = function(opts)
  local merged_routers = M._merge_routers(opts or {})
  Configs = vim.tbl_deep_extend("force", vim.deepcopy(Defaults), opts or {})
  Configs._routers = merged_routers

  return Configs
end

--- @return gitlinker.Options
M.get = function()
  return Configs
end

return M
