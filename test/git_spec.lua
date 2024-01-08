local cwd = vim.fn.getcwd()

describe("git", function()
  local assert_eq = assert.is_equal
  local assert_true = assert.is_true
  local assert_false = assert.is_false

  before_each(function()
    vim.api.nvim_command("cd " .. cwd)
    vim.opt.swapfile = false
    vim.cmd([[ edit lua/gitlinker.lua ]])
  end)

  local async = require("gitlinker.commons.async")
  local git = require("gitlinker.git")
  local path = require("gitlinker.path")
  local gitlinker = require("gitlinker")
  pcall(gitlinker.setup, {})
  describe("[git]", function()
    it("_get_remote", function()
      async.run(function()
        local r = git._get_remote()
        print(string.format("_get_remote:%s\n", vim.inspect(r)))
        assert_eq(type(r), "table")
      end)
    end)
    it("get_remote_url", function()
      async.run(function()
        local remote = git.get_branch_remote()
        print(string.format("get_branch_remote:%s\n", vim.inspect(remote)))
        if remote then
          assert_eq(type(remote), "string")
          assert_true(string.len(remote) > 0)
          local r = git.get_remote_url(remote)
          print(string.format("get_remote_url:%s\n", vim.inspect(r)))
          assert_eq(type(r), "string")
          assert_true(string.len(r) > 0)
        else
          assert_true(remote == nil)
        end
      end)
    end)
    it("_get_rev(@{u})", function()
      async.run(function()
        local rev = git._get_rev("@{u}")
        if rev then
          print(string.format("_get_rev:%s\n", vim.inspect(rev)))
          assert_eq(type(rev), "string")
          assert_true(string.len(rev) > 0)
        else
          assert_true(rev == nil)
        end
      end)
    end)
    it("_get_rev_name(@{u})", function()
      async.run(function()
        local rev = git._get_rev_name("@{u}")
        if rev then
          print(string.format("_get_rev_name:%s\n", vim.inspect(rev)))
          assert_eq(type(rev), "string")
          assert_true(string.len(rev) > 0)
        else
          assert_true(rev == nil)
        end
      end)
    end)
    it("is_file_in_rev", function()
      async.run(function()
        local remote = git.get_branch_remote()
        if not remote then
          assert_true(remote == nil)
          return
        end
        assert_eq(type(remote), "string")
        assert_true(string.len(remote) > 0)
        local remote_url = git.get_remote_url(remote)
        if not remote_url then
          assert_true(remote_url == nil)
          return
        end
        assert_eq(type(remote_url), "string")
        assert_true(string.len(remote_url) > 0)

        local rev = git.get_closest_remote_compatible_rev(remote) --[[@as string]]
        if not rev then
          assert_true(rev == nil)
          return
        end
        assert_eq(type(rev), "string")
        assert_true(string.len(rev) > 0)

        local bufpath = path.buffer_relpath() --[[@as string]]
        if not bufpath then
          assert_true(bufpath == nil)
          return
        end
        local actual = git.is_file_in_rev(bufpath, rev)
        if actual ~= nil then
          print(string.format("is_file_in_rev:%s\n", vim.inspect(actual)))
        else
          assert_true(actual == nil)
        end
      end)
    end)
    it("resolve_host", function()
      async.run(function()
        local actual = git.resolve_host("github.com")
        assert_eq(actual, "github.com")
      end)
    end)
    it("get_default_branch", function()
      async.run(function()
        local actual = git.get_default_branch("origin")
        print(string.format('default branch:%s\n', vim.inspect(actual)))
        assert_eq(actual, "master")
      end)
    end)
    it("get_current_branch", function()
      async.run(function()
        local actual = git.get_current_branch("origin")
                    print(string.format('current branch:%s\n', vim.inspect(actual)))
        assert_eq(actual, "master")
      end)
    end)
  end)
end)
