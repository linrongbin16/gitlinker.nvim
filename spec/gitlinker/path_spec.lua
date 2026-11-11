describe("gitlinker.path", function()
  local assert_eq = assert.is_equal
  local assert_true = assert.is_true

  local path = require("gitlinker.path")

  local original_cwd = vim.fn.getcwd()
  --- A throwaway tree, so the cases never read the files of the repository
  --- this plugin lives in: a rename there would break the spec for a reason
  --- that has nothing to do with `buffer_relpath`.
  --- @type string
  local root

  --- @param p string
  --- @param lines string[]
  local function write(p, lines)
    vim.fn.mkdir(vim.fn.fnamemodify(p, ":h"), "p")
    local fd = assert(io.open(p, "w"))
    fd:write(table.concat(lines, "\n") .. "\n")
    fd:close()
  end

  --- Open `bufpath` in the current buffer and compute its path relative to `dir`.
  --- @param bufpath string
  --- @param dir string?
  --- @return string?
  local function relpath_of(bufpath, dir)
    vim.cmd("edit " .. vim.fn.fnameescape(bufpath))
    return path.buffer_relpath(vim.api.nvim_get_current_buf(), dir)
  end

  before_each(function()
    vim.opt.swapfile = false
    root = vim.fn.tempname()
    write(root .. "/lua/gitlinker/path.lua", { "return {}" })
    write(root .. "/other/file.lua", { "return {}" })
  end)

  after_each(function()
    vim.cmd("cd " .. vim.fn.fnameescape(original_cwd))
    -- Wipe before deleting: a buffer still holding a file in the tree would
    -- otherwise survive the deletion and be reported by later specs.
    vim.cmd("silent! %bwipeout!")
    vim.fn.delete(root, "rf")
  end)

  describe("[buffer_relpath]", function()
    it("returns the path relative to the given directory", function()
      local actual = relpath_of(root .. "/lua/gitlinker/path.lua", root)
      assert_eq(actual, "lua/gitlinker/path.lua")
    end)

    it("returns the path relative to the buffer directory itself", function()
      -- Sanity check for the boundary case where the directory and the buffer
      -- share the same parent: the result is just the file name.
      local bufdir = root .. "/lua/gitlinker"
      local actual = relpath_of(bufdir .. "/path.lua", bufdir)
      assert_eq(actual, "path.lua")
    end)

    it("is not confused by a shared name prefix", function()
      -- `root .. "-other"` starts with `root`, but is not inside `root`.
      local actual = relpath_of(root .. "-other/file.lua", root)
      assert_eq(actual, nil)
    end)

    it("tolerates a trailing separator on the directory", function()
      local actual = relpath_of(root .. "/lua/gitlinker/path.lua", root .. "/")
      assert_eq(actual, "lua/gitlinker/path.lua")
    end)

    it("returns nil when the buffer is outside the directory", function()
      local actual = relpath_of(root .. "/other/file.lua", root .. "/lua")
      assert_eq(actual, nil)
    end)

    it("returns nil for an empty directory", function()
      -- Not a path the plugin passes today, but an empty prefix must not be
      -- treated as "matches everything".
      local actual = relpath_of(root .. "/lua/gitlinker/path.lua", "")
      assert_eq(actual, nil)
    end)

    it("returns nil when the buffer is the directory itself", function()
      -- The directory has no path relative to itself; handing back `""` would
      -- make a link point at the repository root.
      local actual = relpath_of(root .. "/lua", root .. "/lua")
      assert_eq(actual, nil)
    end)

    it("defaults the directory to the editor cwd", function()
      vim.cmd("cd " .. vim.fn.fnameescape(root))
      vim.cmd("edit " .. vim.fn.fnameescape(root .. "/lua/gitlinker/path.lua"))
      local actual = path.buffer_relpath(vim.api.nvim_get_current_buf())
      assert_eq(actual, "lua/gitlinker/path.lua")
    end)

    it("returns nil for an unnamed buffer", function()
      vim.cmd("enew")
      local actual = path.buffer_relpath(vim.api.nvim_get_current_buf(), root)
      assert_eq(actual, nil)
    end)

    it("returns nil for a buffer that no longer exists", function()
      -- The link is built asynchronously, so the buffer may be gone by the
      -- time the path is resolved.
      local bufnr = vim.fn.bufadd(root .. "/lua/gitlinker/path.lua")
      vim.fn.bufload(bufnr)
      vim.cmd("silent! bwipeout! " .. bufnr)
      assert_eq(vim.api.nvim_buf_is_valid(bufnr), false)
      local actual = path.buffer_relpath(bufnr, root)
      assert_eq(actual, nil)
    end)

    it("normalizes a directory written with backslashes", function()
      -- Windows callers hand over `C:\repo\...`; the separator must not change
      -- what counts as "inside".
      local actual = relpath_of(root .. "/lua/gitlinker/path.lua", root:gsub("/", "\\"))
      assert_eq(actual, "lua/gitlinker/path.lua")
    end)
  end)
end)
