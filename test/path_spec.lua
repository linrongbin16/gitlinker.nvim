local cwd = vim.fn.getcwd()

describe("path", function()
  local assert_eq = assert.is_equal
  local assert_true = assert.is_true
  local assert_false = assert.is_false

  before_each(function()
    vim.api.nvim_command("cd " .. cwd)
    vim.opt.swapfile = false
  end)

  local logger = require("gitlinker.logger")
  logger.setup()
  local path = require("gitlinker.path")
end)
