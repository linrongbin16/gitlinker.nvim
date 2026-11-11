local cwd = vim.fn.getcwd()

describe("gitlinker.linker", function()
  local assert_eq = assert.is_equal
  local assert_true = assert.is_true
  local assert_false = assert.is_false

  before_each(function()
    vim.api.nvim_command("cd " .. cwd)
    vim.opt.swapfile = false
    local gitlinker = require("gitlinker")
    pcall(gitlinker.setup, {})
    vim.cmd([[ edit lua/gitlinker.lua ]])
  end)

  local testutil = require("spec.testutil")
  local answering_picker = testutil.answering_picker
  local wait_async = testutil.wait_async
  local linker = require("gitlinker.linker")
  describe("[make_linker]", function()
    it("describes the buffer it is handed", function()
      -- This checkout may have more than one remote, and the builtin picker
      -- would then block on an `inputlist` prompt nobody answers headlessly.
      answering_picker(function()
        wait_async(function()
          local lk, err = linker.make_linker(vim.api.nvim_get_current_buf())
          if lk == nil then
            -- A shallow detached clone in CI may have no remote-tracking refs,
            -- so a failure is allowed there -- but only one that says why.
            assert_eq(type(err), "string")
            assert_true(string.len(err --[[@as string]]) > 0)
            return
          end
          assert_true(err == nil)
          assert_eq(lk.file, "lua/gitlinker.lua")
          -- The range is filled in by `link()`, not here.
          assert_true(lk.lstart == nil)
          assert_true(lk.lend == nil)
          assert_eq(type(lk.rev), "string")
          assert_true(string.len(lk.rev) > 0)
          assert_eq(type(lk.remote_url), "string")
          -- The clone URL depends on how this checkout was made (https vs ssh,
          -- with or without the `.git` suffix), so assert on the parts the
          -- linker must preserve instead of a literal URL.
          assert_true(lk.remote_url:match("github%.com/linrongbin16/gitlinker%.nvim$") ~= nil)
          assert_eq(lk.org, "linrongbin16")
          assert_eq(lk.repo, "gitlinker.nvim")
          -- `make_linker` reports a missing default branch and carries on, it
          -- does not fail: `get_default_branch` reads the `refs/remotes/<remote>/HEAD`
          -- symref, and a detached checkout -- what `actions/checkout` leaves
          -- behind -- has none. The link still builds, the router just renders
          -- an empty `DEFAULT_BRANCH`, so pin both shapes here rather than the
          -- one a full clone happens to have.
          assert_true(lk.default_branch == nil or lk.default_branch == "master")
          assert_eq(type(lk.current_branch), "string")
          assert_true(string.len(lk.current_branch) > 0)
        end)
      end)
    end)
    it("returns an error for an unknown rev", function()
      answering_picker(function()
        wait_async(function()
          local lk, err = linker.make_linker(
            vim.api.nvim_get_current_buf(),
            nil,
            nil,
            "definitely-not-a-real-rev-xyz"
          )
          assert_true(lk == nil)
          assert_eq(type(err), "string")
          assert_true(string.len(err --[[@as string]]) > 0)
        end)
      end)
    end)
    it("returns an error outside a git repository", function()
      local tmp = vim.fn.tempname()
      vim.fn.mkdir(tmp, "p")
      vim.fn.writefile({ "plain" }, tmp .. "/plain.txt")
      vim.cmd("edit " .. vim.fn.fnameescape(tmp .. "/plain.txt"))
      local bufnr = vim.api.nvim_get_current_buf()
      wait_async(function()
        local lk, err = linker.make_linker(bufnr)
        assert_true(lk == nil)
        assert_eq(type(err), "string")
        assert_true(string.len(err --[[@as string]]) > 0)
      end)
      -- Close the buffer first: deleting a directory that a loaded buffer still
      -- points at leaves it holding a path that no longer exists.
      vim.cmd("silent! enew!")
      vim.fn.delete(tmp, "rf")
    end)
    it("returns an error for an unknown remote", function()
      wait_async(function()
        local lk, err =
          linker.make_linker(vim.api.nvim_get_current_buf(), "no-such-remote-xyz", nil, nil)
        assert_true(lk == nil)
        assert_eq(type(err), "string")
        -- The message has to name the remote the user asked for, otherwise it
        -- does not say which of their remotes was wrong.
        assert_true(err --[[@as string]]:find("no-such-remote-xyz", 1, true) ~= nil, err)
      end)
    end)
    it("returns an error for a local path remote", function()
      --- Run `args` and fail loudly when it exits non-zero: a silently broken
      --- fixture would otherwise surface as a confusing assertion error later.
      --- @param args string[]
      local function sh(args)
        local out = vim.fn.system(args)
        assert_eq(vim.v.shell_error, 0, string.format("%s => %s", table.concat(args, " "), out))
      end

      local upstream = vim.fn.tempname()
      local repo = vim.fn.tempname()
      vim.fn.mkdir(upstream, "p")
      vim.fn.mkdir(repo, "p")
      sh({ "git", "init", "--quiet", "-b", "main", upstream })
      sh({ "git", "-C", upstream, "config", "user.email", "test@example.com" })
      sh({ "git", "-C", upstream, "config", "user.name", "test" })
      sh({ "git", "-C", upstream, "config", "commit.gpgsign", "false" })
      sh({ "git", "-C", upstream, "commit", "--quiet", "--allow-empty", "--message", "init" })
      sh({ "git", "init", "--quiet", "-b", "main", repo })
      sh({ "git", "-C", repo, "config", "user.email", "test@example.com" })
      sh({ "git", "-C", repo, "config", "user.name", "test" })
      sh({ "git", "-C", repo, "config", "commit.gpgsign", "false" })
      sh({ "git", "-C", repo, "commit", "--quiet", "--allow-empty", "--message", "init" })
      -- A remote that points at a directory on this machine. It is a valid git
      -- remote, but it has no web host, so there is no permalink to build.
      sh({ "git", "-C", repo, "remote", "add", "origin", upstream })
      sh({ "git", "-C", repo, "remote", "add", "file-remote", "file://" .. upstream })
      vim.cmd("edit " .. repo .. "/plain.txt")
      -- Read the buffer number before suspending: `nvim_get_current_buf` is not
      -- allowed from the fast event context `wait_async` runs the body in.
      local bufnr = vim.api.nvim_get_current_buf()
      -- One `wait_async` per remote: `make_linker` reads the buffer before its
      -- first `await`, and a second call in the same resumed body would run in
      -- a fast event context, where that read is rejected.
      for _, remote in ipairs({ "origin", "file-remote" }) do
        wait_async(function()
          local lk, err = linker.make_linker(bufnr, remote, nil, nil)
          assert_true(lk == nil, string.format("remote %s: %s", remote, vim.inspect(lk)))
          assert_eq(type(err), "string")
          -- The message has to name the cause. It used to be ssh's multi-line
          -- usage text, which told the user nothing about their remote.
          assert_true(err:find("local path remotes are not supported", 1, true) ~= nil, err)
          assert_true(err:find(upstream, 1, true) ~= nil, err)
        end)
      end
      -- Close the buffer before deleting the directory it was loaded from.
      vim.cmd("silent! enew!")
      vim.fn.delete(repo, "rf")
      vim.fn.delete(upstream, "rf")
    end)
  end)
end)
