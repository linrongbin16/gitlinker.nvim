local cwd = vim.fn.getcwd()

describe("gitlinker.git", function()
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
        local r, err = git._get_remote(cwd)
        print(string.format("_get_remote:%s, err:%s\n", vim.inspect(r), vim.inspect(err)))
        if r then
          assert_eq(type(r), "table")
          assert_true(#r > 0)
          assert_true(err == nil)
        else
          assert_eq(type(err), "string")
        end
      end)
    end)
    it("get_remote_url", function()
      async.run(function()
        local remote, remote_err = git.get_branch_remote(cwd)
        print(
          string.format(
            "get_branch_remote:%s, err:%s\n",
            vim.inspect(remote),
            vim.inspect(remote_err)
          )
        )
        if remote then
          assert_eq(type(remote), "string")
          assert_true(string.len(remote) > 0)
          local r, err = git.get_remote_url(remote, cwd)
          print(string.format("get_remote_url:%s, err:%s\n", vim.inspect(r), vim.inspect(err)))
          if r then
            assert_eq(type(r), "string")
            assert_true(string.len(r) > 0)
            assert_true(err == nil)
          else
            assert_eq(type(err), "string")
          end
        else
          assert_eq(type(remote_err), "string")
        end
      end)
    end)
    it("_get_rev(@{u})", function()
      async.run(function()
        local rev, err = git._get_rev("@{u}", cwd)
        print(string.format("_get_rev:%s, err:%s\n", vim.inspect(rev), vim.inspect(err)))
        if rev then
          assert_eq(type(rev), "string")
          assert_true(string.len(rev) > 0)
          assert_true(err == nil)
        else
          assert_eq(type(err), "string")
        end
      end)
    end)
    it("_get_rev with an unknown revspec reports an error", function()
      async.run(function()
        local rev, err = git._get_rev("definitely-not-a-real-rev-xyz", cwd)
        print(string.format("_get_rev(bad):%s, err:%s\n", vim.inspect(rev), vim.inspect(err)))
        -- `git rev-parse` exits non-zero but still echoes the argument on
        -- stdout, so this must rely on the exit code rather than stdout.
        assert_true(rev == nil)
        assert_eq(type(err), "string")
        assert_true(string.len(err) > 0)
      end)
    end)
    it("_get_rev_name(@{u})", function()
      async.run(function()
        local rev, err = git._get_rev_name("@{u}", cwd)
        print(string.format("_get_rev_name:%s, err:%s\n", vim.inspect(rev), vim.inspect(err)))
        if rev then
          assert_eq(type(rev), "string")
          assert_true(string.len(rev) > 0)
          assert_true(err == nil)
        else
          assert_eq(type(err), "string")
        end
      end)
    end)
    it("is_file_in_rev", function()
      async.run(function()
        local remote = git.get_branch_remote(cwd)
        if not remote then
          return
        end
        local remote_url = git.get_remote_url(remote, cwd)
        if not remote_url then
          return
        end
        local rev = git.get_closest_remote_compatible_rev(remote, cwd) --[[@as string]]
        if not rev then
          return
        end

        local bufpath = path.buffer_relpath() --[[@as string]]
        if not bufpath then
          return
        end
        local actual, err = git.is_file_in_rev(bufpath, rev, cwd)
        print(string.format("is_file_in_rev:%s, err:%s\n", vim.inspect(actual), vim.inspect(err)))
        if actual then
          assert_true(actual)
          assert_true(err == nil)
        else
          assert_eq(type(err), "string")
        end
      end)
    end)
    it("is_file_in_rev reports an error for a missing file", function()
      async.run(function()
        local rev = git._get_rev("HEAD", cwd)
        if not rev then
          return
        end
        local actual, err = git.is_file_in_rev("no/such/file-xyz.lua", rev, cwd)
        print(
          string.format(
            "is_file_in_rev(missing):%s, err:%s\n",
            vim.inspect(actual),
            vim.inspect(err)
          )
        )
        assert_true(actual == nil)
        assert_eq(type(err), "string")
      end)
    end)
    it("resolve_host", function()
      async.run(function()
        local actual, err = git.resolve_host("github.com", cwd)
        print(string.format("resolve_host:%s, err:%s\n", vim.inspect(actual), vim.inspect(err)))
        assert_eq(actual, "github.com")
        assert_true(err == nil)
      end)
    end)
    it("get_default_branch", function()
      async.run(function()
        local actual, err = git.get_default_branch("origin", cwd)
        print(string.format("default branch:%s, err:%s\n", vim.inspect(actual), vim.inspect(err)))
        if actual then
          assert_eq(type(actual), "string")
          assert_true(err == nil)
        else
          assert_eq(type(err), "string")
        end
      end)
    end)
    it("get_current_branch", function()
      async.run(function()
        local actual, err = git.get_current_branch(cwd)
        print(string.format("current branch:%s, err:%s\n", vim.inspect(actual), vim.inspect(err)))
        if actual then
          assert_eq(type(actual), "string")
          assert_true(err == nil)
        else
          assert_eq(type(err), "string")
        end
      end)
    end)
    it("get_root", function()
      async.run(function()
        local actual, err = git.get_root(cwd)
        print(string.format("get_root:%s, err:%s\n", vim.inspect(actual), vim.inspect(err)))
        if actual then
          assert_eq(type(actual), "string")
          assert_true(err == nil)
        else
          assert_eq(type(err), "string")
        end
      end)
    end)
    it("returns an error instead of raising when cwd does not exist", function()
      async.run(function()
        local actual, err = git.get_root("/definitely-not-a-real-dir-xyz")
        print(
          string.format("get_root(bad cwd):%s, err:%s\n", vim.inspect(actual), vim.inspect(err))
        )
        assert_true(actual == nil)
        assert_eq(type(err), "string")
      end)
    end)
  end)
end)
