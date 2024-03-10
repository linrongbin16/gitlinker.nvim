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

  describe("[highlight]", function()
    local URL =
      "https://github.com/axieax/urlview.nvim/blob/b183133fd25caa6dd98b415e0f62e51e061cd522/lua/urlview/actions.lua#L38"
    it("copy to clipboard", function()
      actions.clipboard(URL)
    end)
    it("open in browser", function()
      actions.system(URL)
    end)
  end)
end)
