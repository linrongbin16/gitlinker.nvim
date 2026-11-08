local cwd = vim.fn.getcwd()

describe("gitlinker.highlight", function()
  local assert_eq = assert.is_equal
  local assert_true = assert.is_true
  local assert_false = assert.is_false

  before_each(function()
    vim.api.nvim_command("cd " .. cwd)
  end)

  require("gitlinker").setup()
  local highlight = require("gitlinker.highlight")
  local ns = vim.api.nvim_create_namespace(highlight.NAMESPACE)

  --- Return the extmarks `highlight.show` created, waiting for its scheduled
  --- callback to run.
  --- @param bufnr integer Buffer to read.
  --- @return {[1]:integer,[2]:integer,[3]:integer,[4]:table}[]
  local function shown_marks(bufnr)
    assert_true(vim.wait(1000, function()
      return #vim.api.nvim_buf_get_extmarks(bufnr, ns, 0, -1, {}) > 0
    end, 10))
    return vim.api.nvim_buf_get_extmarks(bufnr, ns, 0, -1, { details = true })
  end

  --- Drop every mark this suite left in `bufnr`.
  ---
  --- Tests clear between cases; the module no longer offers a function for it
  --- because nothing in `lua/` needs one. Note that wiping the whole namespace
  --- restarts the extmark id counter, while the per-call timer in `show` only
  --- deletes the ids it created: a wipe between a short highlight and a later
  --- one would let the first timer take the second highlight. Tests do not run
  --- long enough for a stale timer to survive into the next case, so this is
  --- safe here and must not be copied into `lua/`.
  --- @param bufnr integer Buffer to wipe.
  local function wipe(bufnr)
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
    end
  end

  --- Build the `start_pos`/`finish_pos` pair the way `gitlinker.lua` does.
  --- @param lstart integer
  --- @param lend integer?
  --- @return {[1]:{integer,integer},[2]:{integer,integer}}
  local function make_pos(lstart, lend)
    local llast = lend or lstart
    return {
      { lstart - 1, 0 },
      { llast - 1, vim.fn.col({ llast, "$" }) },
    }
  end

  describe("[highlight]", function()
    local bufnr
    before_each(function()
      bufnr = vim.api.nvim_get_current_buf()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "abcdef", "ghijkl" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      wipe(bufnr)
    end)
    it("exists sees a defined group", function()
      vim.api.nvim_set_hl(0, "ProbeDefined", { link = "Search" })
      assert_true(highlight.exists("ProbeDefined"))
    end)
    it("exists rejects a group that was never defined", function()
      assert_false(highlight.exists("ProbeNeverDefined"))
    end)
    it("exists rejects a group whose attributes were cleared", function()
      -- A colorscheme switch empties the definitions without dropping the ids,
      -- so a check that asks for the id reports a group that draws nothing.
      vim.api.nvim_set_hl(0, "ProbeCleared", { link = "Search" })
      vim.api.nvim_set_hl(0, "ProbeCleared", {})
      assert_eq(vim.fn.hlexists("ProbeCleared"), 1)
      assert_false(highlight.exists("ProbeCleared"))
    end)
    it("exists does not define the group it looks up", function()
      -- `nvim_get_hl()` creates the group unless told otherwise, which would
      -- make the second lookup of a missing group report it as present.
      highlight.exists("ProbeSideEffect")
      assert_eq(vim.fn.hlexists("ProbeSideEffect"), 0)
    end)
    it("show", function()
      highlight.show(make_pos(1, 1), bufnr, 10000)
      shown_marks(bufnr)
    end)
    it("show covers the first character of the start line", function()
      highlight.show(make_pos(1, 1), bufnr, 10000)
      local marks = shown_marks(bufnr)
      assert_eq(#marks, 1)
      -- Columns are 0-based: column 1 would drop the leading "a".
      assert_eq(marks[1][3], 0)
      assert_eq(marks[1][4].end_col, 6)
    end)
    it("show covers the whole line range", function()
      highlight.show(make_pos(1, 2), bufnr, 10000)
      local marks = shown_marks(bufnr)
      assert_eq(#marks, 1)
      assert_eq(marks[1][2], 0)
      assert_eq(marks[1][3], 0)
      -- The range is inclusive, so it ends on the last character of `lend`.
      assert_eq(marks[1][4].end_row, 1)
      assert_eq(marks[1][4].end_col, 6)
    end)
    it("make_pos sizes the end column from the end line, not the cursor line", function()
      -- Lines that differ in length, with the cursor parked on a line that is
      -- not the end of the range: a `col("$")` that reads the cursor line
      -- would clip the last line to the width of the first.
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "abcdef", "ghijklmnopqrst" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      wipe(bufnr)
      highlight.show(make_pos(1, 2), bufnr, 10000)
      local marks = shown_marks(bufnr)
      assert_eq(#marks, 1)
      assert_eq(marks[1][4].end_row, 1)
      assert_eq(marks[1][4].end_col, 14)
    end)
    it("show targets the given buffer, not the current one", function()
      -- A caller builds the positions while its own buffer is current, then
      -- hands the pair over: by the time `show` runs the current buffer may be
      -- a different one.
      local origin = bufnr
      vim.api.nvim_buf_set_lines(origin, 0, -1, false, { "abcdef", "ghijkl" })
      local pos = make_pos(1, 2)

      local other = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(other, 0, -1, false, { "x", "y" })
      vim.api.nvim_set_current_buf(other)
      vim.api.nvim_win_set_cursor(0, { 1, 0 })

      highlight.show(pos, origin, 10000)
      local marks = shown_marks(origin)
      assert_eq(#marks, 1)
      -- `ghijkl` is 6 bytes wide, so the end column must come from the origin
      -- buffer, not from the one currently displayed.
      assert_eq(marks[1][4].end_row, 1)
      assert_eq(marks[1][4].end_col, 6)
      assert_eq(#vim.api.nvim_buf_get_extmarks(other, ns, 0, -1, {}), 0)

      vim.api.nvim_set_current_buf(origin)
      vim.api.nvim_buf_delete(other, { force = true })
    end)
    it("show survives a buffer that was deleted first", function()
      local doomed = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(doomed, 0, -1, false, { "abcdef" })
      -- The positions are built while the buffer is still alive, so `show` only
      -- has to cope with it disappearing afterwards.
      local pos = make_pos(1, 1)
      local id = doomed
      vim.api.nvim_buf_delete(doomed, { force = true })
      assert_true(pcall(highlight.show, pos, id, 10000))
    end)
    describe("[link]", function()
      -- End to end: `gitlinker.lua` builds the positions and hands them over.
      -- The buffer has to sit in a git repository that has a remote, which the
      -- checkout this suite runs from is not guaranteed to be, so build a
      -- throwaway one instead of relying on the surrounding environment.
      local repo
      local file

      --- Run `args` and fail loudly when it exits non-zero: a silently broken
      --- fixture would otherwise surface as a confusing assertion error later.
      --- @param args string[]
      local function sh(args)
        local out = vim.fn.system(args)
        assert_eq(vim.v.shell_error, 0, string.format("%s => %s", table.concat(args, " "), out))
      end

      before_each(function()
        repo = vim.fn.tempname()
        file = repo .. "/demo.txt"
        vim.fn.mkdir(repo, "p")
        local fd = assert(io.open(file, "w"))
        fd:write("short\na much longer second line\n")
        fd:close()

        sh({ "git", "init", "--quiet", "-b", "main", repo })
        sh({ "git", "-C", repo, "config", "user.email", "test@example.com" })
        sh({ "git", "-C", repo, "config", "user.name", "test" })
        sh({ "git", "-C", repo, "config", "commit.gpgsign", "false" })
        sh({ "git", "-C", repo, "add", "--all" })
        sh({ "git", "-C", repo, "commit", "--quiet", "--message", "init" })
        -- The url is only parsed, never contacted. The tracking refs are
        -- created by hand because these tests must not touch the network: the
        -- linker refuses to link a revision the remote does not have.
        sh({
          "git",
          "-C",
          repo,
          "remote",
          "add",
          "origin",
          "https://github.com/acme/demo.git",
        })
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
        vim.cmd("edit! " .. vim.fn.fnameescape(file))
        vim.api.nvim_win_set_cursor(0, { 1, 0 })
      end)

      after_each(function()
        vim.cmd("silent! enew!")
        vim.fn.delete(repo, "rf")
      end)

      it("highlights the requested lines of the buffer it started in", function()
        local origin = vim.api.nvim_get_current_buf()
        wipe(origin)

        local confs = require("gitlinker.configs").get()
        local saved = confs.highlight_duration
        confs.highlight_duration = 5000
        local ok = pcall(require("gitlinker")._void_link, {
          action = function() end,
          router = function()
            return "https://example.com/x"
          end,
          lstart = 1,
          lend = 2,
        })
        confs.highlight_duration = saved
        assert_true(ok)

        local marks = shown_marks(origin)
        assert_eq(#marks, 1)
        assert_eq(marks[1][2], 0)
        assert_eq(marks[1][3], 0)
        -- The end column is the width of line 2, read while the cursor was still
        -- on line 1: measuring the cursor line would give 6 instead of 25.
        assert_eq(marks[1][4].end_row, 1)
        assert_eq(marks[1][4].end_col, 25)
        wipe(origin)
      end)

      it("clears after the duration given to link, not the configured one", function()
        local origin = vim.api.nvim_get_current_buf()
        wipe(origin)

        local confs = require("gitlinker.configs").get()
        local saved = confs.highlight_duration
        -- Far longer than the caller asks for, so a timer fed from the config
        -- rather than from the option is still pending when the wait below
        -- gives up. Keep the value in place for the whole test: `_link` reads
        -- it from inside a scheduled callback, long after `_void_link` returns.
        confs.highlight_duration = 5000
        local ok = pcall(require("gitlinker")._void_link, {
          action = function() end,
          router = function()
            return "https://example.com/x"
          end,
          lstart = 1,
          lend = 2,
          highlight_duration = 50,
        })
        assert_true(ok)

        assert_eq(#shown_marks(origin), 1)
        -- Wait well past the requested duration but nowhere near the configured
        -- one: the mark has to be gone long before the config would clear it.
        local cleared = vim.wait(1000, function()
          return #vim.api.nvim_buf_get_extmarks(origin, ns, 0, -1, {}) == 0
        end, 10)
        confs.highlight_duration = saved
        assert_true(cleared)
      end)

      it("an earlier highlight expires without clearing a later one", function()
        local origin = vim.api.nvim_get_current_buf()
        wipe(origin)

        local function link(lstart, duration)
          return assert_true(pcall(require("gitlinker")._void_link, {
            action = function() end,
            router = function()
              return "https://example.com/x"
            end,
            lstart = lstart,
            lend = lstart,
            highlight_duration = duration,
          }))
        end

        local function count()
          return #vim.api.nvim_buf_get_extmarks(origin, ns, 0, -1, {})
        end

        link(1, 1200)
        assert_true(vim.wait(1000, function()
          return count() == 1
        end, 10))
        link(2, 10000)
        assert_true(vim.wait(1000, function()
          return count() == 2
        end, 10))

        -- The first highlight expires on its own schedule. It must take only
        -- its own extmark: the second one is still far inside its duration.
        assert_true(vim.wait(2000, function()
          return count() == 1
        end, 10))
        local marks = vim.api.nvim_buf_get_extmarks(origin, ns, 0, -1, {})
        assert_eq(marks[1][2], 1)
        wipe(origin)
      end)
    end)
  end)
end)
