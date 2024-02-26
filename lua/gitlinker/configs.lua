local M = {}

local Defaults = {
  -- print permanent url in command line
  message = true,

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
      ["^bitbucket%.org"] = "https://bitbucket.org/"
        .. "{_A.ORG}/"
        .. "{_A.REPO}/src/"
        .. "{_A.REV}/"
        .. "{_A.FILE}"
        .. "#lines-{_A.LSTART}"
        .. "{(_A.LEND > _A.LSTART and (':' .. _A.LEND) or '')}",
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
      ["^bitbucket%.org"] = "https://bitbucket.org/"
        .. "{_A.ORG}/"
        .. "{_A.REPO}/annotate/"
        .. "{_A.REV}/"
        .. "{_A.FILE}"
        .. "#lines-{_A.LSTART}"
        .. "{(_A.LEND > _A.LSTART and (':' .. _A.LEND) or '')}",
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
      ["^bitbucket%.org"] = "https://bitbucket.org/"
        .. "{_A.ORG}/"
        .. "{_A.REPO}/src/"
        .. "{_A.DEFAULT_BRANCH}/"
        .. "{_A.FILE}"
        .. "#lines-{_A.LSTART}"
        .. "{(_A.LEND > _A.LSTART and (':' .. _A.LEND) or '')}",
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
--- @return table<string, {list_routers:table,map_routers:table}>
M._merge_routers = function(opts)
  local result = {}

  -- users list
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
    end
  end

  -- default map
  for default_router_type, default_router_bindings in pairs(Defaults.router) do
    if result[default_router_type] == nil then
      result[default_router_type] = {}
      result[default_router_type].list_routers = {}
      result[default_router_type].map_routers = {}
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

  -- default list
  for default_router_type, default_router_bindings in pairs(Defaults.router) do
    -- list
    for i, tuple in ipairs(default_router_bindings) do
      if type(i) == "number" and type(tuple) == "table" and #tuple == 2 then
        table.insert(result[default_router_type].list_routers, tuple)
      end
    end
  end

  -- user map
  if type(opts.router) == "table" then
    for user_router_type, user_router_bindings in pairs(opts.router) do
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
