local cwd = vim.fn.getcwd()

describe("gitlinker.path", function()
  local assert_eq = assert.is_equal
  local assert_true = assert.is_true
  local assert_false = assert.is_false

  local path = require("gitlinker.path")

  --- Open `bufpath` in the current buffer and compute its path relative to `dir`.
  --- @param bufpath string
  --- @param dir string?
  --- @return string?
  local function relpath_of(bufpath, dir)
    vim.cmd("edit " .. vim.fn.fnameescape(bufpath))
    return path.buffer_relpath(dir)
  end

  describe("[buffer_relpath]", function()
    it("returns the path relative to the given directory", function()
      local root = cwd
      local actual = relpath_of(root .. "/lua/gitlinker/path.lua", root)
      assert_eq(actual, "lua/gitlinker/path.lua")
    end)

    it("returns the path relative to the buffer directory itself", function()
      -- Sanity check for the boundary case where the directory and the buffer
      -- share the same parent: the result is just the file name.
      local bufdir = cwd .. "/lua/gitlinker"
      local actual = relpath_of(bufdir .. "/path.lua", bufdir)
      assert_eq(actual, "path.lua")
    end)

    it("is not confused by a shared name prefix", function()
      -- `/repo-other` starts with `/repo`, but is not inside `/repo`.
      local actual = relpath_of(cwd .. "-other/file.lua", cwd)
      assert_true(actual == nil)
    end)

    it("tolerates a trailing separator on the directory", function()
      local actual = relpath_of(cwd .. "/lua/gitlinker/path.lua", cwd .. "/")
      assert_eq(actual, "lua/gitlinker/path.lua")
    end)

    it("returns nil when the buffer is outside the directory", function()
      local actual = relpath_of("/tmp/file-outside-gitlinker.lua", cwd)
      assert_true(actual == nil)
    end)

    it("returns nil for an empty directory", function()
      -- Not a path the plugin passes today, but an empty prefix must not be
      -- treated as "matches everything".
      local actual = relpath_of(cwd .. "/lua/gitlinker/path.lua", "")
      assert_true(actual == nil)
    end)
  end)
end)
