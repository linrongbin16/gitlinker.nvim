local cwd = vim.fn.getcwd()

describe("gitlinker.routers", function()
  local assert_eq = assert.is_equal
  local assert_true = assert.is_true
  local assert_false = assert.is_false

  before_each(function()
    vim.api.nvim_command("cd " .. cwd)
    vim.opt.swapfile = false
    local gitlinker = require("gitlinker")
    pcall(gitlinker.setup, {})
    vim.cmd([[ edit lua/gitlinker.lua ]])
  end)

  local routers = require("gitlinker.routers")
  local github_actions = os.getenv("GITHUB_ACTIONS") == "true"
  local linker = require("gitlinker.linker")
  describe("[samba_browse]", function()
    it("test1", function()
      local lk = {
        current_branch = "dev-plugin",
        default_branch = "main",
        file = "vim.toml",
        file_changed = false,
        host = "github.com",
        lend = 1,
        lstart = 1,
        org = "linrongbin16",
        protocol = "https",
        remote_url = "https://github.com/linrongbin16/lin.nvim",
        repo = "lin.nvim",
        rev = "e3ef741ac8814fc0895e26772c5059af2f064543",
        user = "linrongbin16",
      }
      local actual = routers.samba_browse(lk)
      print(string.format("samba_browse:%s", vim.inspect(actual)))
      assert_eq(
        actual,
        "https://git.samba.org/?p=linrongbin16/lin.nvim;a=blob;f=vim.toml;hb=e3ef741ac8814fc0895e26772c5059af2f064543#l1"
      )
    end)
    it("test2", function()
      local lk = {
        current_branch = "dev-plugin",
        default_branch = "main",
        file = "README.md",
        file_changed = false,
        host = "github.com",
        lend = 1,
        lstart = 1,
        org = "linrongbin16",
        protocol = "https",
        remote_url = "https://github.com/linrongbin16/lin.nvim",
        repo = "lin.nvim",
        rev = "e3ef741ac8814fc0895e26772c5059af2f064543",
        user = "linrongbin16",
      }
      local actual = routers.samba_browse(lk)
      print(string.format("samba_browse:%s", vim.inspect(actual)))
      assert_eq(
        actual,
        "https://git.samba.org/?p=linrongbin16/lin.nvim;a=blob;f=README.md;hb=e3ef741ac8814fc0895e26772c5059af2f064543#l1"
      )
    end)
  end)
end)
