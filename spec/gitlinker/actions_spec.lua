local cwd = vim.fn.getcwd()

describe("gitlinker.actions", function()
  local assert_eq = assert.is_equal
  local assert_true = assert.is_true
  local assert_false = assert.is_false

  before_each(function()
    vim.api.nvim_command("cd " .. cwd)
  end)

  local actions = require("gitlinker.actions")
  require("gitlinker").setup()

  describe("[actions]", function()
    local URL =
      "https://github.com/linrongbin16/gitlinker.nvim/blob/1801ed9513fd4a1f0bff3440dcca7b0ea656a508/spec/gitlinker_spec.lua?plain=1#L3"
    it("clipboard", function()
      actions.clipboard(URL)
    end)
    it("system", function()
      actions.system(URL)
    end)
  end)
end)
