local cwd = vim.fn.getcwd()

describe("gitlinker", function()
  local assert_eq = assert.is_equal
  local assert_true = assert.is_true
  local assert_false = assert.is_false

  vim.api.nvim_command("cd " .. cwd)
  before_each(function() end)

  local configs = require("gitlinker.configs")

  describe("[_merge_routers]", function()
    it("test map bindings", function()
      local actual = configs._merge_routers({
        router = {
          browse = {
            ["^git%.xyz%.com"] = "https://git.xyz.com/browse",
          },
          blame = {
            ["^git%.xyz%.com"] = "https://git.xyz.com/blame",
          },
        },
      })

      print(string.format("merged routers:%s\n", vim.inspect(actual)))
      local browse_list = actual.browse.list_routers
      local browse_map = actual.browse.map_routers
      local blame_list = actual.blame.list_routers
      local blame_map = actual.blame.map_routers

      assert_eq(#browse_list, 0)
      do
        local browse_n = 0
        for k, v in pairs(browse_map) do
          if k == "^github%.com" then
            browse_n = browse_n + 1
          elseif k == "^gitlab%.com" then
            browse_n = browse_n + 1
          elseif k == "^bitbucket%.org" then
            browse_n = browse_n + 1
          elseif k == "^codeberg%.org" then
            browse_n = browse_n + 1
          elseif k == "^git%.samba%.org" then
            browse_n = browse_n + 1
          elseif k == "^git%.xyz%.com" then
            assert_eq(v, "https://git.xyz.com/browse")
            browse_n = browse_n + 1
          end
        end
        assert_eq(browse_n, 6)
      end

      assert_eq(#blame_list, 0)
      do
        local blame_n = 0
        for k, v in pairs(blame_map) do
          if k == "^github%.com" then
            blame_n = blame_n + 1
          elseif k == "^gitlab%.com" then
            blame_n = blame_n + 1
          elseif k == "^bitbucket%.org" then
            blame_n = blame_n + 1
          elseif k == "^codeberg%.org" then
            blame_n = blame_n + 1
          elseif k == "^git%.xyz%.com" then
            assert_eq(v, "https://git.xyz.com/blame")
            blame_n = blame_n + 1
          end
        end
        assert_eq(blame_n, 5)
      end
    end)
    it("test list bindings", function()
      local actual = configs._merge_routers({
        router = {
          browse = {
            {
              "^https://git%.xyz%.com/linrongbin16/gitlinker.nvim",
              "https://git.xyz.com/linrongbin16/gitlinker.nvim/browse",
            },
            { "^git%.xyz%.com", "https://git.xyz.com/browse" },
          },
          blame = {
            {
              "^https://git%.xyz%.com/linrongbin16/gitlinker.nvim",
              "https://git.xyz.com/linrongbin16/gitlinker.nvim/blame",
            },
            { "^git%.xyz%.com", "https://git.xyz.com/blame" },
          },
        },
      })

      local browse_list = actual.browse.list_routers
      local browse_map = actual.browse.map_routers
      local blame_list = actual.blame.list_routers
      local blame_map = actual.blame.map_routers

      assert_eq(#browse_list, 2)
      do
        local browse_m = 0
        for _, tuple in ipairs(browse_list) do
          local p = tuple[1]
          local r = tuple[2]
          if p == "^https://git%.xyz%.com/linrongbin16/gitlinker.nvim" then
            assert_eq(r, "https://git.xyz.com/linrongbin16/gitlinker.nvim/browse")
            browse_m = browse_m + 1
          elseif p == "^git%.xyz%.com" then
            assert_eq(r, "https://git.xyz.com/browse")
            browse_m = browse_m + 1
          end
        end
        assert_eq(browse_m, 2)
      end

      do
        local browse_n = 0
        for k, v in pairs(browse_map) do
          if k == "^github%.com" then
            browse_n = browse_n + 1
          elseif k == "^gitlab%.com" then
            browse_n = browse_n + 1
          elseif k == "^bitbucket%.org" then
            browse_n = browse_n + 1
          elseif k == "^codeberg%.org" then
            browse_n = browse_n + 1
          elseif k == "^git%.samba%.org" then
            browse_n = browse_n + 1
          end
        end
        assert_eq(browse_n, 5)
      end

      assert_eq(#blame_list, 2)
      do
        local blame_m = 0
        for _, tuple in ipairs(blame_list) do
          local p = tuple[1]
          local r = tuple[2]
          if p == "^https://git%.xyz%.com/linrongbin16/gitlinker.nvim" then
            assert_eq(r, "https://git.xyz.com/linrongbin16/gitlinker.nvim/blame")
            blame_m = blame_m + 1
          elseif p == "^git%.xyz%.com" then
            assert_eq(r, "https://git.xyz.com/blame")
            blame_m = blame_m + 1
          end
        end
        assert_eq(blame_m, 2)
      end

      do
        local blame_n = 0
        for k, v in pairs(blame_map) do
          if k == "^github%.com" then
            blame_n = blame_n + 1
          elseif k == "^gitlab%.com" then
            blame_n = blame_n + 1
          elseif k == "^bitbucket%.org" then
            blame_n = blame_n + 1
          elseif k == "^codeberg%.org" then
            blame_n = blame_n + 1
          end
        end
        assert_eq(blame_n, 4)
      end
    end)
  end)
end)
