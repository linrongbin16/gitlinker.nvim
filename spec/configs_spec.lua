local cwd = vim.fn.getcwd()

describe("gitlinker", function()
  local assert_eq = assert.is_equal
  local assert_true = assert.is_true
  local assert_false = assert.is_false

  local gitlinker = require("gitlinker")

  before_each(function()
    vim.api.nvim_command("cd " .. cwd)
    vim.opt.swapfile = false
    pcall(gitlinker.setup, {
      debug = true,
      file_log = true,
      router = {
        browse = {
          ["^git%.xyz%.com"] = "https://git.xyz.com/"
            .. "{_A.USER}/"
            .. "{_A.REPO}/blob/"
            .. "{_A.REV}/"
            .. "{_A.FILE}?plain=1"
            .. "#L{_A.LSTART}"
            .. "{(_A.LEND > _A.LSTART and ('-L' .. _A.LEND) or '')}",
        },
        blame = {
          ["^git%.xyz%.com"] = "https://git.xyz.com/"
            .. "{_A.USER}/"
            .. "{_A.REPO}/blame/"
            .. "{_A.REV}/"
            .. "{_A.FILE}?plain=1"
            .. "#L{_A.LSTART}"
            .. "{(_A.LEND > _A.LSTART and ('-L' .. _A.LEND) or '')}",
        },
        default_branch = {
          ["^github%.com"] = "https://github.com/"
            .. "{_A.ORG}/"
            .. "{_A.REPO}/blob/"
            .. "{_A.DEFAULT_BRANCH}/" -- always 'master'/'main' branch
            .. "{_A.FILE}?plain=1" -- '?plain=1'
            .. "#L{_A.LSTART}"
            .. "{(_A.LEND > _A.LSTART and ('-L' .. _A.LEND) or '')}",
        },
        current_branch = {
          ["^github%.com"] = "https://github.com/"
            .. "{_A.ORG}/"
            .. "{_A.REPO}/blob/"
            .. "{_A.CURRENT_BRANCH}/" -- always current branch
            .. "{_A.FILE}?plain=1" -- '?plain=1'
            .. "#L{_A.LSTART}"
            .. "{(_A.LEND > _A.LSTART and ('-L' .. _A.LEND) or '')}",
        },
      },
    })
    vim.cmd([[ edit lua/gitlinker.lua ]])
  end)

  local routers = require("gitlinker.routers")
  describe("[_browse]", function()
    it("git.samba.org/samba.git with same lstart/lend", function()
      local lk = {
        remote_url = "git@git.samba.org:samba.git",
        protocol = nil,
        username = "git",
        password = nil,
        host = "git.samba.org",
        org = "",
        repo = "samba.git",
        rev = "399b1d05473c711fc5592a6ffc724e231c403486",
        file = "wscript",
        file_changed = false,
        lstart = 13,
        lend = 13,
      } --[[@as gitlinker.Linker]]
      local actual = gitlinker._browse(lk)
      assert_eq(
        actual,
        "https://git.samba.org/?p=samba.git;a=blob;f=wscript;hb=399b1d05473c711fc5592a6ffc724e231c403486#l13"
      )
      assert_eq(actual, routers.samba_browse(lk))
    end)
  end)
end)
