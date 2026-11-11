--- Regression tests for the "run git in the repository root" contract.
---
--- `git diff <pathspec>` resolves the pathspec against the process working
--- directory, while `git cat-file <rev>:<path>` always resolves against the
--- repository root. Running the commands in the buffer directory therefore made
--- the two disagree, and a pathspec that matched nothing made `git diff` exit 0
--- with empty output -- reported as "the file has not changed".

-- Some tests below `cd` into a throwaway repository, which would break the
-- relative `.` runtimepath entry from `spec_init.lua`. Pin the plugin root as
-- an absolute path so the lazy `require` calls keep resolving.
vim.opt.rtp:append(vim.fn.getcwd())
--- The repository this spec file lives in, resolved once before anything `cd`s
--- away from it.
local plugin_root = vim.fn.resolve(vim.fn.getcwd())

describe("gitlinker root semantics", function()
  local assert_eq = assert.is_equal
  local assert_true = assert.is_true
  local assert_false = assert.is_false

  local git = require("gitlinker.git")
  local linker = require("gitlinker.linker")
  local async = require("gitlinker.async")
  local wait_async = require("spec.testutil").wait_async

  local original_cwd = vim.fn.getcwd()
  --- @type string
  local repo
  --- @type string
  local sub

  --- Run `args` and fail loudly when it exits non-zero: a silently broken
  --- fixture would otherwise surface as a confusing assertion error later.
  --- @param args string[]
  --- @return string
  local function sh(args)
    local out = vim.fn.system(args)
    local code = vim.v.shell_error
    assert_eq(code, 0, string.format("%s => %s", table.concat(args, " "), out))
    return out
  end

  --- @param path string
  --- @param lines string
  local function write(path, lines)
    local fd = assert(io.open(path, "w"))
    fd:write(lines)
    fd:close()
  end

  before_each(function()
    vim.opt.swapfile = false
    repo = vim.fn.tempname()
    sub = repo .. "/sub"
    vim.fn.mkdir(sub, "p")

    sh({ "git", "init", "--quiet", "-b", "main", repo })
    sh({ "git", "-C", repo, "config", "user.email", "test@example.com" })
    sh({ "git", "-C", repo, "config", "user.name", "test" })
    sh({ "git", "-C", repo, "config", "commit.gpgsign", "false" })
    write(repo .. "/root.txt", "root\n")
    write(sub .. "/a.txt", "sub\n")
    sh({ "git", "-C", repo, "add", "--all" })
    sh({ "git", "-C", repo, "commit", "--quiet", "--message", "init" })
    -- The URL is never contacted; the linker only parses it. The tracking refs
    -- are created by hand because these tests must not touch the network: the
    -- linker refuses to link a revision the remote does not have.
    sh({ "git", "-C", repo, "remote", "add", "origin", "https://github.com/acme/demo.git" })
    sh({ "git", "-C", repo, "update-ref", "refs/remotes/origin/main", "HEAD" })
    sh({
      "git",
      "-C",
      repo,
      "symbolic-ref",
      "refs/remotes/origin/HEAD",
      "refs/remotes/origin/main",
    })
    sh({ "git", "-C", repo, "branch", "--set-upstream-to=origin/main", "main" })
  end)

  after_each(function()
    vim.cmd("cd " .. vim.fn.fnameescape(original_cwd))
    vim.cmd("silent! enew!")
    vim.fn.delete(repo, "rf")
  end)

  it("resolves the repository root from a nested directory", function()
    wait_async(function()
      local root, err = git.get_root(sub)
      assert_eq(err, nil)
      assert_eq(vim.fn.resolve(root), vim.fn.resolve(repo))
    end)
  end)

  it("looks files up relative to the root, not the buffer directory", function()
    wait_async(function()
      -- `git rev-parse --show-toplevel` reports the real path, so normalize
      -- before comparing: the temp directory may itself sit behind a symlink.
      local root, root_err = git.get_root(sub)
      assert_true(root ~= nil, "this test needs the repository root: " .. tostring(root_err))
      assert_eq(vim.fn.resolve(root --[[@as string]]), vim.fn.resolve(repo))

      local nested, nested_err = git.is_file_in_rev("sub/a.txt", "HEAD", root --[[@as string]])
      assert_eq(nested_err, nil)
      assert_true(nested)

      -- The same file name without the `sub/` prefix does not exist in the
      -- tree: `cat-file` always resolves `rev:path` from the repository root.
      local shallow, shallow_err = git.is_file_in_rev("a.txt", "HEAD", root --[[@as string]])
      assert_true(shallow == nil)
      assert_eq(type(shallow_err), "string")
      -- The message has to name the path that was looked for, otherwise the
      -- user cannot tell which file the link points at.
      assert_true(
        shallow_err --[[@as string]]:find("a.txt", 1, true) ~= nil,
        "unexpected error: " .. tostring(shallow_err)
      )
    end)
  end)

  it("detects a change to a file nested one level down", function()
    wait_async(function()
      local root, root_err = git.get_root(sub)
      assert_true(root ~= nil, "this test needs the repository root: " .. tostring(root_err))

      local clean, clean_err = git.file_has_changed("sub/a.txt", "HEAD", root --[[@as string]])
      assert_eq(clean_err, nil)
      assert_false(clean)

      write(sub .. "/a.txt", "sub\nchanged\n")

      -- A pathspec that matches nothing exits 0 with empty output, so this
      -- used to come back as `false` no matter what the working tree held.
      local dirty, dirty_err = git.file_has_changed("sub/a.txt", "HEAD", root --[[@as string]])
      assert_eq(dirty_err, nil)
      assert_true(dirty)
    end)
  end)

  it("links a buffer in a nested directory with a root-relative path", function()
    wait_async(function()
      -- The editor cwd is the repository root, the buffer sits one level
      -- below: `path.buffer_relpath()` then yields `sub/a.txt`, while the git
      -- commands used to run in `sub`, where that pathspec matches nothing.
      vim.cmd("cd " .. vim.fn.fnameescape(repo))
      vim.cmd("edit " .. vim.fn.fnameescape(sub .. "/a.txt"))

      local lk, lk_err = linker.make_linker(vim.api.nvim_get_current_buf()) --[[@as gitlinker.Linker, string?]]
      assert_true(lk ~= nil, "this test needs a link: " .. tostring(lk_err))
      assert_eq(lk.file, "sub/a.txt")
      assert_false(lk.file_changed)

      -- The coroutine resumes in a fast event context once `git` exits, so
      -- every editor command needs a hop back to the main loop first.
      async.await(1, vim.schedule)
      write(sub .. "/a.txt", "sub\nchanged\n")
      vim.cmd("edit!")

      local lk_changed, changed_err = linker.make_linker(vim.api.nvim_get_current_buf()) --[[@as gitlinker.Linker, string?]]
      assert_true(lk_changed ~= nil, "this test needs a link: " .. tostring(changed_err))
      assert_eq(lk_changed.file, "sub/a.txt")
      assert_true(lk_changed.file_changed)
    end)
  end)

  it("reports a missing repository instead of guessing a root", function()
    -- A directory outside any repository has no root. `get_root` must say so
    -- rather than hand back the directory it was given, which would make every
    -- later `cat-file` run against an unrelated working tree.
    local outside = vim.fn.tempname()
    vim.fn.mkdir(outside, "p")
    wait_async(function()
      local root, err = git.get_root(outside)
      assert_true(root == nil, "unexpected root: " .. vim.inspect(root))
      assert_eq(type(err), "string")
      assert_true(string.len(err --[[@as string]]) > 0)
    end)
    vim.fn.delete(outside, "rf")
  end)

  it("pins the plugin root independently of the editor cwd", function()
    -- The suite `cd`s into throwaway repositories, so the runtimepath entry
    -- this spec added has to be absolute: a relative `.` would stop resolving
    -- `require("gitlinker...")` the moment the cwd moves.
    assert_true(
      vim.fn.isdirectory(plugin_root .. "/lua/gitlinker") == 1,
      "plugin root is not a directory: " .. plugin_root
    )
    vim.cmd("cd " .. vim.fn.fnameescape(repo))
    assert_eq(vim.fn.getcwd(), repo)
    assert_eq(require("gitlinker.range") ~= nil, true)
  end)
end)
