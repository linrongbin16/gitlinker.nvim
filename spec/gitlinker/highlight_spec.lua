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
  describe("[highlight]", function()
    it("show", function()
      highlight.show({ lstart = 1, lend = 1 })
    end)
    it("clear", function()
      highlight.clear()
    end)
  end)
end)
