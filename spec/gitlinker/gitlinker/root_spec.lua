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

describe("gitlinker root semantics", function()
  local assert_eq = assert.is_equal
  local assert_true = assert.is_true
  local assert_false = assert.is_false

  local git = require("gitlinker.git")
  local linker = require("gitlinker.linker")
  local async = require("gitlinker.commons.async")
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
      local root = git.get_root(sub) --[[@as string]]
      assert_eq(vim.fn.resolve(root), vim.fn.resolve(repo))

      local nested, nested_err = git.is_file_in_rev("sub/a.txt", "HEAD", root)
      assert_eq(nested_err, nil)
      assert_true(nested)

      -- The same file name without the `sub/` prefix does not exist in the
      -- tree: `cat-file` always resolves `rev:path` from the repository root.
      local shallow, shallow_err = git.is_file_in_rev("a.txt", "HEAD", root)
      assert_true(shallow == nil)
      assert_eq(type(shallow_err), "string")
    end)
  end)

  it("detects a change to a file nested one level down", function()
    wait_async(function()
      local root = git.get_root(sub) --[[@as string]]

      local clean, clean_err = git.file_has_changed("sub/a.txt", "HEAD", root)
      assert_eq(clean_err, nil)
      assert_false(clean)

      write(sub .. "/a.txt", "sub\nchanged\n")

      -- A pathspec that matches nothing exits 0 with empty output, so this
      -- used to come back as `false` no matter what the working tree held.
      local dirty, dirty_err = git.file_has_changed("sub/a.txt", "HEAD", root)
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

      local lk, lk_err = linker.make_linker() --[[@as gitlinker.Linker, string?]]
      assert_eq(lk_err, nil)
      assert_eq(lk.file, "sub/a.txt")
      assert_false(lk.file_changed)

      -- The coroutine resumes in a fast event context once `git` exits, so
      -- every editor command needs a hop back to the main loop first.
      async.await(1, vim.schedule)
      write(sub .. "/a.txt", "sub\nchanged\n")
      vim.cmd("edit!")

      local lk_changed = linker.make_linker() --[[@as gitlinker.Linker]]
      assert_eq(lk_changed.file, "sub/a.txt")
      assert_true(lk_changed.file_changed)
    end)
  end)
end)
