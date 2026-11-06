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

  local wait_async = require("spec.testutil").wait_async
  local git = require("gitlinker.git")
  local path = require("gitlinker.path")
  local gitlinker = require("gitlinker")
  pcall(gitlinker.setup, {})

  describe("[git]", function()
    it("_get_remote", function()
      wait_async(function()
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
      wait_async(function()
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
      wait_async(function()
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
      wait_async(function()
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
      wait_async(function()
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
      -- `path.buffer_relpath` calls Vimscript functions (`getcwd`, `resolve`),
      -- which cannot run in the fast event context the coroutine resumes in
      -- after `git` exits. Compute it here, exactly like `linker.make_linker`
      -- does when it hops back with `async.await(1, vim.schedule)`.
      local bufpath = path.buffer_relpath(cwd)
      wait_async(function()
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
      wait_async(function()
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
      wait_async(function()
        local actual, err = git.resolve_host("github.com", cwd)
        print(string.format("resolve_host:%s, err:%s\n", vim.inspect(actual), vim.inspect(err)))
        assert_eq(actual, "github.com")
        assert_true(err == nil)
      end)
    end)
    it("get_default_branch", function()
      wait_async(function()
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
      wait_async(function()
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
      wait_async(function()
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
      wait_async(function()
        local actual, err = git.get_root("/definitely-not-a-real-dir-xyz")
        print(
          string.format("get_root(bad cwd):%s, err:%s\n", vim.inspect(actual), vim.inspect(err))
        )
        assert_true(actual == nil)
        assert_eq(type(err), "string")
      end)
    end)
    it("distinguishes a spawn failure from a failing command", function()
      wait_async(function()
        -- A missing cwd makes vim.system raise before the command ever runs.
        local root, spawn_err = git.get_root("/definitely-not-a-real-dir-xyz")
        assert_true(root == nil)
        assert_eq(type(spawn_err), "string")
        assert_true(string.find(spawn_err, "ENOENT", 1, true) ~= nil)

        local result = git.GitResult:new()
        assert_eq(result.code, 0)
        assert_true(result:ok())
        assert_false(result:spawn_failed())

        -- A real exit status must never look like a spawn failure. `255` and
        -- `-1` are what a plainly failed command reports.
        for _, code in ipairs({ 1, 128, 255, -1 }) do
          local failed = git.GitResult:new()
          failed.code = code
          assert_false(failed:ok())
          assert_false(failed:spawn_failed())
        end

        local spawn_failed = git.GitResult:new()
        spawn_failed.code = git.GitResult.SPAWN_FAILED
        assert_false(spawn_failed:ok())
        assert_true(spawn_failed:spawn_failed())

        -- The sentinel is INT32_MIN, far outside the exit-status range shells
        -- produce, and exactly representable as a Lua number.
        assert_eq(git.GitResult.SPAWN_FAILED, -2147483648)
        assert_true(git.GitResult.SPAWN_FAILED < 0)
        assert_true(git.GitResult.SPAWN_FAILED ~= -1)
        assert_eq(tonumber(tostring(git.GitResult.SPAWN_FAILED)), -2147483648)
        assert_eq(tonumber(string.format("%d", git.GitResult.SPAWN_FAILED)), -2147483648)
      end)
    end)
    it("silent_failed covers a failing command and an empty success", function()
      wait_async(function()
        -- Succeeded, but printed nothing: there is no value to hand back.
        local silent = git.GitResult:new()
        assert_eq(silent.code, 0)
        assert_true(silent:ok())
        assert_true(silent:silent_failed())

        -- Succeeded with output: usable.
        local ok = git.GitResult:new()
        ok.stdout = { "some-value" }
        assert_true(ok:ok())
        assert_false(ok:silent_failed())

        -- Failed, with or without output: unusable.
        for _, code in ipairs({ 1, 128, 255, git.GitResult.SPAWN_FAILED }) do
          local failed = git.GitResult:new()
          failed.code = code
          failed.stdout = { "stale output" }
          assert_false(failed:ok())
          assert_true(failed:silent_failed())
        end

        -- `git cat-file -e` reports success by exiting 0 without printing
        -- anything, so it must keep checking ok() alone; silent_failed() would
        -- turn every successful probe into a failure.
        local probe = git.GitResult:new()
        assert_true(probe:ok())
        assert_true(probe:silent_failed())
        local exists, probe_err =
          git.is_file_in_rev("lua/gitlinker/git.lua", "HEAD", vim.fn.getcwd())
        assert_true(exists)
        assert_true(probe_err == nil)
      end)
    end)
  end)
end)
