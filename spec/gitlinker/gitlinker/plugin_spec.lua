local cwd = vim.fn.getcwd()

describe("gitlinker.plugin", function()
  local assert_eq = assert.is_equal
  local assert_true = assert.is_true
  local assert_nil = assert.is_nil

  before_each(function()
    vim.api.nvim_command("cd " .. cwd)
    vim.opt.swapfile = false
    vim.g.loaded_gitlinker = nil
    package.loaded["gitlinker"] = nil
  end)

  it("plugin file creates command without loading module", function()
    vim.cmd("source plugin/gitlinker.lua")
    assert_true(vim.api.nvim_get_commands({})["GitLink"] ~= nil)
    assert_nil(package.loaded["gitlinker"])
  end)

  it("setup twice is idempotent", function()
    local gitlinker = require("gitlinker")
    gitlinker.setup({})
    gitlinker.setup({})
    assert_true(vim.api.nvim_get_commands({})["GitLink"] ~= nil)
  end)

  it("plugin file then setup doesn't error", function()
    vim.cmd("source plugin/gitlinker.lua")
    local gitlinker = require("gitlinker")
    gitlinker.setup({})
    assert_true(vim.api.nvim_get_commands({})["GitLink"] ~= nil)
  end)

  it("setup with custom command name removes default one", function()
    local gitlinker = require("gitlinker")
    gitlinker.setup({ command = { name = "MyGitLink", desc = "My git link" } })
    assert_true(vim.api.nvim_get_commands({})["MyGitLink"] ~= nil)
    assert_nil(vim.api.nvim_get_commands({})["GitLink"])
  end)

  it("plugin file respects disable guard", function()
    vim.g.loaded_gitlinker = 1
    vim.cmd("source plugin/gitlinker.lua")
    assert_nil(vim.api.nvim_get_commands({})["GitLink"])
    assert_nil(package.loaded["gitlinker"])
  end)

  it("_complete returns sorted router types", function()
    local gitlinker = require("gitlinker")
    gitlinker.setup({})
    local actual = gitlinker._complete("")
    assert_true(#actual >= 4)
    assert_eq(actual[1], "blame")
    assert_eq(actual[2], "browse")
  end)

  it("_complete filters by prefix", function()
    local gitlinker = require("gitlinker")
    gitlinker.setup({})
    local actual = gitlinker._complete("current")
    assert_eq(#actual, 1)
    assert_eq(actual[1], "current_branch")
  end)

  it("_complete works without setup", function()
    local gitlinker = require("gitlinker")
    local actual = gitlinker._complete("b")
    assert_true(#actual >= 2)
  end)
end)
