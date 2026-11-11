local cwd = vim.fn.getcwd()

describe("gitlinker.configs", function()
  local assert_eq = assert.is_equal
  local assert_true = assert.is_true
  local assert_false = assert.is_false
  local assert_same = assert.same

  local configs = require("gitlinker.configs")

  before_each(function()
    vim.api.nvim_command("cd " .. cwd)
  end)

  --- Count the keys of a table. `#` is meaningless here: `map_routers` is
  --- keyed by the host pattern, so it is not a sequence.
  --- @param t table
  --- @return integer
  local function count(t)
    local n = 0
    for _ in pairs(t) do
      n = n + 1
    end
    return n
  end

  --- The patterns `Defaults.router` ships for a router type, so a case can tell
  --- "the default is still there" from "the default is gone".
  --- @param router_type string
  --- @return string[]
  local function default_patterns(router_type)
    local patterns = {}
    for pattern, _ in pairs(configs._merge_routers({})[router_type].map_routers) do
      table.insert(patterns, pattern)
    end
    table.sort(patterns)
    return patterns
  end

  describe("[_merge_routers]", function()
    it("keeps the built-in map bindings when the user gives none", function()
      local actual = configs._merge_routers({})
      for _, router_type in ipairs({ "browse", "blame", "default_branch" }) do
        assert_true(actual[router_type] ~= nil, "missing router type: " .. router_type)
        assert_same(actual[router_type].list_routers, {})
        local patterns = default_patterns(router_type)
        assert_true(#patterns > 0, "no default bindings for " .. router_type)
        for _, pattern in ipairs(patterns) do
          assert_eq(
            type(actual[router_type].map_routers[pattern]),
            "string",
            string.format("%s is missing its default route for %s", router_type, pattern)
          )
        end
      end
    end)

    it("tolerates a missing or non-table opts", function()
      for _, opts in ipairs({ nil, {}, { router = 1 }, { router = "x" } }) do
        local actual = configs._merge_routers(opts)
        assert_eq(
          type(actual.browse.map_routers["^github%.com"]),
          "string",
          string.format("opts: %s", vim.inspect(opts))
        )
      end
    end)

    it("adds a user map binding next to the defaults", function()
      local actual = configs._merge_routers({
        router = {
          browse = {
            ["^git%.xyz%.com"] = "https://git.xyz.com/browse",
          },
        },
      })

      assert_same(actual.browse.list_routers, {})
      assert_eq(actual.browse.map_routers["^git%.xyz%.com"], "https://git.xyz.com/browse")
      -- The new host joins the defaults rather than replacing them.
      for _, pattern in ipairs(default_patterns("browse")) do
        assert_eq(
          type(actual.browse.map_routers[pattern]),
          "string",
          "the default route for " .. pattern .. " was dropped"
        )
      end
      -- The other router types are untouched.
      assert_eq(actual.blame.map_routers["^git%.xyz%.com"], nil)
    end)

    it("lets a user map binding override a default one", function()
      local override = "https://proxy.example.com/{_A.ORG}/{_A.REPO}/blob/{_A.REV}/{_A.FILE}"
      local actual = configs._merge_routers({
        router = {
          browse = {
            ["^github%.com"] = override,
          },
        },
      })
      -- A user route has to win over the built-in one, otherwise a proxy or a
      -- self-hosted mirror cannot be configured at all.
      assert_eq(actual.browse.map_routers["^github%.com"], override)
      assert_eq(
        count(actual.browse.map_routers),
        #default_patterns("browse"),
        "overriding must not add or remove a key"
      )
    end)

    it("prepends list bindings so the last one wins", function()
      local actual = configs._merge_routers({
        router = {
          browse = {
            { "^first%.example%.com", "https://first.example.com/browse" },
            { "^second%.example%.com", "https://second.example.com/browse" },
          },
        },
      })

      -- Later entries are inserted at the head, so the list is walked in
      -- reverse order of declaration: the most recently configured rule wins.
      assert_same(actual.browse.list_routers, {
        { "^second%.example%.com", "https://second.example.com/browse" },
        { "^first%.example%.com", "https://first.example.com/browse" },
      })
      assert_same(actual.blame.list_routers, {})
      -- List bindings live beside the map ones, not instead of them.
      assert_eq(type(actual.browse.map_routers["^github%.com"]), "string")
    end)

    it("keeps a function route callable", function()
      local route = function(lk)
        return "https://fn.example.com/" .. lk.repo
      end
      local actual = configs._merge_routers({
        router = {
          browse = {
            { "^fn%.example%.com", route },
            ["^map%.example%.com"] = route,
          },
        },
      })
      assert_eq(actual.browse.list_routers[1][2], route)
      assert_eq(actual.browse.map_routers["^map%.example%.com"], route)
    end)

    it("drops malformed bindings instead of storing them", function()
      local actual = configs._merge_routers({
        router = {
          browse = {
            { "^no-route.example.com" }, -- a tuple needs two entries
            { "^too-many.example.com", "https://a", "https://b" },
            "not-a-tuple",
            ["^bad-route%.example%.com"] = 42, -- a route is a string or a function
            [""] = "https://empty-pattern.example.com",
            [42] = "https://number-pattern.example.com",
          },
        },
      })

      assert_same(actual.browse.list_routers, {})
      assert_eq(actual.browse.map_routers["^bad-route%.example%.com"], nil)
      assert_eq(actual.browse.map_routers[""], nil)
      assert_eq(actual.browse.map_routers[42], nil)
      assert_eq(actual.browse.map_routers["^no-route.example.com"], nil)
      assert_eq(actual.browse.map_routers["^too-many.example.com"], nil)
    end)

    it("creates a router type the defaults do not have", function()
      local actual = configs._merge_routers({
        router = {
          custom = {
            ["^custom%.example%.com"] = "https://custom.example.com/browse",
          },
        },
      })
      assert_eq(
        actual.custom.map_routers["^custom%.example%.com"],
        "https://custom.example.com/browse"
      )
      assert_same(actual.custom.list_routers, {})
    end)
  end)

  describe("[setup]", function()
    local gitlinker = require("gitlinker")

    after_each(function()
      -- Put the default configuration back: every later spec file shares this
      -- module, so a custom router left behind would leak into it.
      gitlinker.setup({})
    end)

    it("stores the merged configuration where `get` reads it", function()
      local returned = configs.setup({ debug = true })
      assert_true(returned ~= nil)
      assert_eq(returned.debug, true)
      assert_eq(configs.get(), returned)
      -- The routers are merged into the stored configuration, so a lookup by
      -- host has something to find.
      assert_eq(type(returned._routers.browse.map_routers["^github%.com"]), "string")
    end)

    it("fills in the defaults for the keys it was not given", function()
      local returned = configs.setup({})
      assert_eq(returned.debug, false)
      assert_eq(returned.console_log, true)
      assert_eq(returned.file_log, false)
      assert_eq(returned.clipboard_override, false)
      assert_eq(returned.message, true)
      assert_eq(returned.warn_on_file_change, true)
      assert_eq(returned.highlight_duration, 500)
      assert_eq(returned.command.name, "GitLink")
      assert_eq(type(returned._routers), "table")
      assert_eq(type(returned._routers.browse.map_routers["^github%.com"]), "string")
    end)

    it("registers the user command", function()
      gitlinker.setup({})
      assert_true(vim.fn.exists(":GitLink") == 2, "GitLink is not a command")
      local command = vim.api.nvim_get_commands({})["GitLink"]
      assert_true(command ~= nil)
      -- The command takes a range and a bang, and completes router types.
      assert_true(command.nargs == "*", vim.inspect(command.nargs))
      local complete = vim.fn.getcompletion("GitLink ", "cmdline")
      assert_true(#complete > 0, "GitLink completes nothing")
      for _, name in ipairs(complete) do
        assert_eq(type(name), "string")
      end
      assert_true(vim.tbl_contains(complete, "browse"), vim.inspect(complete))
    end)
  end)
end)
