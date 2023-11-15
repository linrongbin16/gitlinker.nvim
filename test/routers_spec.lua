local cwd = vim.fn.getcwd()

describe("routers", function()
  local assert_eq = assert.is_equal
  local assert_true = assert.is_true
  local assert_false = assert.is_false

  before_each(function()
    vim.api.nvim_command("cd " .. cwd)
    vim.opt.swapfile = false
  end)

  local utils = require("gitlinker.utils")
  local Linker = require("gitlinker.linker").Linker
  local routers = require("gitlinker.routers")
  require("gitlinker").setup({
    debug = true,
    file_log = true,
  })
  describe("[blob]", function()
    it("without line numbers", function()
      local actual = routers.blob({
        remote_url = "git@github.com:linrongbin16/gitlinker.nvim.git",
        protocol = "git",
        host = "github.com",
        user = "linrongbin16",
        repo = "gitlinker.nvim.git",
        rev = "399b1d05473c711fc5592a6ffc724e231c403486",
        file = "lua/gitlinker/logger.lua",
        file_changed = false,
      } --[[@as Linker]])
      assert_eq(
        actual,
        "https://github.com/linrongbin16/gitlinker.nvim/blob/399b1d05473c711fc5592a6ffc724e231c403486/lua/gitlinker/logger.lua"
      )
    end)
    it("with line start", function()
      local actual = routers.blob({
        remote_url = "git@github.com:linrongbin16/gitlinker.nvim.git",
        protocol = "git",
        host = "github.com",
        user = "linrongbin16",
        repo = "gitlinker.nvim.git",
        rev = "399b1d05473c711fc5592a6ffc724e231c403486",
        file = "lua/gitlinker/logger.lua",
        lstart = 1,
        lend = 1,
        file_changed = false,
      }--[[@as Linker]])
      assert_eq(
        actual,
        "https://github.com/linrongbin16/gitlinker.nvim/blob/399b1d05473c711fc5592a6ffc724e231c403486/lua/gitlinker/logger.lua#L1"
      )
    end)
    it("with same line start and line end", function()
      local actual = routers.blob({
        remote_url = "git@github.com:linrongbin16/gitlinker.nvim.git",
        protocol = "git",
        host = "github.com",
        user = "linrongbin16",
        repo = "gitlinker.nvim.git",
        rev = "399b1d05473c711fc5592a6ffc724e231c403486",
        file = "lua/gitlinker/logger.lua",
        lstart = 1,
        lend = 1,
        file_changed = false,
      }--[[@as Linker]])
      assert_eq(
        actual,
        "https://github.com/linrongbin16/gitlinker.nvim/blob/399b1d05473c711fc5592a6ffc724e231c403486/lua/gitlinker/logger.lua#L1"
      )
    end)
    it("with different line start and line end", function()
      local actual = routers.blob({
        remote_url = "git@github.com:linrongbin16/gitlinker.nvim.git",
        protocol = "git",
        host = "github.com",
        user = "linrongbin16",
        repo = "gitlinker.nvim.git",
        rev = "399b1d05473c711fc5592a6ffc724e231c403486",
        file = "lua/gitlinker/logger.lua",
        lstart = 2,
        lend = 5,
        file_changed = false,
      }--[[@as Linker]])
      assert_eq(
        actual,
        "https://github.com/linrongbin16/gitlinker.nvim/blob/399b1d05473c711fc5592a6ffc724e231c403486/lua/gitlinker/logger.lua#L2-L5"
      )
    end)
    it("with Linker", function()
      local actual = routers.blob(Linker:make({
        lstart = 2,
        lend = 5,
      })--[[@as Linker]])
      assert_true(
        utils.string_startswith(
          actual,
          "https://github.com/linrongbin16/gitlinker.nvim/blob/"
        )
      )
      assert_true(utils.string_endswith(actual, "#L2-L5"))
    end)
  end)
end)
