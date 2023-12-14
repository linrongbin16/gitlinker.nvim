local cwd = vim.fn.getcwd()

describe("gitlinker", function()
  local assert_eq = assert.is_equal
  local assert_true = assert.is_true
  local assert_false = assert.is_false

  local gitlinker = require("gitlinker")

  before_each(function()
    vim.api.nvim_command("cd " .. cwd)
    vim.opt.swapfile = false
    gitlinker.setup({
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
            .. "{_A.USER}/"
            .. "{_A.REPO}/blob/"
            .. "{_A.DEFAULT_BRANCH}/" -- always 'master'/'main' branch
            .. "{_A.FILE}?plain=1" -- '?plain=1'
            .. "#L{_A.LSTART}"
            .. "{(_A.LEND > _A.LSTART and ('-L' .. _A.LEND) or '')}",
        },
        current_branch = {
          ["^github%.com"] = "https://github.com/"
            .. "{_A.USER}/"
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
        protocol = "git@",
        host = "git.samba.org",
        host_delimiter = ":",
        user = "",
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
    it("git.samba.org/samba.git with different lstart/lend", function()
      local lk = {
        remote_url = "https://git.samba.org/samba.git",
        protocol = "https://",
        host = "git.samba.org",
        host_delimiter = "/",
        user = "",
        repo = "samba.git",
        rev = "399b1d05473c711fc5592a6ffc724e231c403486",
        file = "wscript",
        file_changed = false,
        lstart = 12,
        lend = 37,
      }--[[@as gitlinker.Linker]]
      local actual = gitlinker._browse(lk)
      assert_eq(
        actual,
        "https://git.samba.org/?p=samba.git;a=blob;f=wscript;hb=399b1d05473c711fc5592a6ffc724e231c403486#l12"
      )
      assert_eq(actual, routers.samba_browse(lk))
    end)
    it("git.samba.org/bbaumbach/samba.git with same lstart/lend", function()
      local lk = {
        remote_url = "git@git.samba.org:bbaumbach/samba.git",
        protocol = "git@",
        host = "git.samba.org",
        host_delimiter = ":",
        user = "bbaumbach",
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
        "https://git.samba.org/?p=bbaumbach/samba.git;a=blob;f=wscript;hb=399b1d05473c711fc5592a6ffc724e231c403486#l13"
      )
      assert_eq(actual, routers.samba_browse(lk))
    end)
    it(
      "git.samba.org/bbaumbach/samba.git with different lstart/lend",
      function()
        local lk = {
          remote_url = "https://git.samba.org/bbaumbach/samba.git",
          protocol = "https://",
          host = "git.samba.org",
          host_delimiter = "/",
          user = "bbaumbach",
          repo = "samba.git",
          rev = "399b1d05473c711fc5592a6ffc724e231c403486",
          file = "wscript",
          file_changed = false,
          lstart = 12,
          lend = 37,
        }--[[@as gitlinker.Linker]]
        local actual = gitlinker._browse(lk)
        assert_eq(
          actual,
          "https://git.samba.org/?p=bbaumbach/samba.git;a=blob;f=wscript;hb=399b1d05473c711fc5592a6ffc724e231c403486#l12"
        )
        assert_eq(actual, routers.samba_browse(lk))
      end
    )
    it("github with same lstart/lend", function()
      local lk = {
        remote_url = "git@github.com:linrongbin16/gitlinker.nvim.git",
        protocol = "git@",
        host = "github.com",
        user = "linrongbin16",
        repo = "gitlinker.nvim.git",
        rev = "399b1d05473c711fc5592a6ffc724e231c403486",
        file = "lua/gitlinker/logger.lua",
        file_changed = false,
        lstart = 13,
        lend = 47,
      } --[[@as gitlinker.Linker]]
      local actual = gitlinker._browse(lk)
      assert_eq(
        actual,
        "https://github.com/linrongbin16/gitlinker.nvim/blob/399b1d05473c711fc5592a6ffc724e231c403486/lua/gitlinker/logger.lua?plain=1#L13-L47"
      )
      assert_eq(actual, routers.github_browse(lk))
    end)
    it("github with different lstart/lend", function()
      local lk = {
        remote_url = "git@github.com:linrongbin16/gitlinker.nvim.git",
        protocol = "git@",
        host = "github.com",
        user = "linrongbin16",
        repo = "gitlinker.nvim.git",
        rev = "399b1d05473c711fc5592a6ffc724e231c403486",
        file = "lua/gitlinker/logger.lua",
        lstart = 1,
        lend = 1,
        file_changed = false,
      }--[[@as gitlinker.Linker]]
      local actual = gitlinker._browse(lk)
      assert_eq(
        actual,
        "https://github.com/linrongbin16/gitlinker.nvim/blob/399b1d05473c711fc5592a6ffc724e231c403486/lua/gitlinker/logger.lua?plain=1#L1"
      )
      assert_eq(actual, routers.github_browse(lk))
    end)
    it("ssh://git@git.xyz.com with same lstart/lend", function()
      local lk = {
        remote_url = "ssh://git@git.xyz.com/linrongbin16/gitlinker.nvim.git",
        protocol = "ssh://git@",
        host = "git.xyz.com",
        host_delimiter = "/",
        user = "linrongbin16",
        repo = "gitlinker.nvim.git",
        rev = "399b1d05473c711fc5592a6ffc724e231c403486",
        file = "lua/gitlinker/logger.lua",
        file_changed = false,
        lstart = 13,
        lend = 47,
      } --[[@as gitlinker.Linker]]
      local actual = gitlinker._browse(lk)
      assert_eq(
        actual,
        "https://git.xyz.com/linrongbin16/gitlinker.nvim/blob/399b1d05473c711fc5592a6ffc724e231c403486/lua/gitlinker/logger.lua?plain=1#L13-L47"
      )
      assert_eq(actual, routers.github_browse(lk))
    end)
    it("ssh://git@git.xyz.com with different lstart/lend", function()
      local lk = {
        remote_url = "ssh://git@github.com:linrongbin16/gitlinker.nvim.git",
        protocol = "ssh://git@",
        host = "git.xyz.com",
        host_delimiter = ":",
        user = "linrongbin16",
        repo = "gitlinker.nvim.git",
        rev = "399b1d05473c711fc5592a6ffc724e231c403486",
        file = "lua/gitlinker/logger.lua",
        lstart = 1,
        lend = 1,
        file_changed = false,
      }--[[@as gitlinker.Linker]]
      local actual = gitlinker._browse(lk)
      assert_eq(
        actual,
        "https://git.xyz.com/linrongbin16/gitlinker.nvim/blob/399b1d05473c711fc5592a6ffc724e231c403486/lua/gitlinker/logger.lua?plain=1#L1"
      )
      assert_eq(actual, routers.github_browse(lk))
    end)
    it("gitlab with same line start and line end", function()
      local lk = {
        remote_url = "https://gitlab.com/linrongbin16/gitlinker.nvim.git",
        protocol = "https://",
        host = "gitlab.com",
        user = "linrongbin16",
        repo = "gitlinker.nvim.git",
        rev = "399b1d05473c711fc5592a6ffc724e231c403486",
        file = "lua/gitlinker/logger.lua",
        lstart = 3,
        lend = 3,
        file_changed = false,
      }--[[@as gitlinker.Linker]]
      local actual = gitlinker._browse(lk)
      assert_eq(
        actual,
        "https://gitlab.com/linrongbin16/gitlinker.nvim/blob/399b1d05473c711fc5592a6ffc724e231c403486/lua/gitlinker/logger.lua#L3"
      )
      assert_eq(actual, routers.gitlab_browse(lk))
    end)
    it("gitlab with different line start and line end", function()
      local lk = {
        remote_url = "git@gitlab.com:linrongbin16/gitlinker.nvim.git",
        protocol = "git@",
        host = "gitlab.com",
        user = "linrongbin16",
        repo = "gitlinker.nvim.git",
        rev = "399b1d05473c711fc5592a6ffc724e231c403486",
        file = "lua/gitlinker/logger.lua",
        lstart = 2,
        lend = 5,
        file_changed = false,
      }--[[@as gitlinker.Linker]]
      local actual = gitlinker._browse(lk)
      assert_eq(
        actual,
        "https://gitlab.com/linrongbin16/gitlinker.nvim/blob/399b1d05473c711fc5592a6ffc724e231c403486/lua/gitlinker/logger.lua#L2-L5"
      )
      assert_eq(actual, routers.gitlab_browse(lk))
    end)
    it("bitbucket with same line start and line end", function()
      local lk = {
        remote_url = "git@bitbucket.org:linrongbin16/gitlinker.nvim.git",
        protocol = "git@",
        host = "bitbucket.org",
        user = "linrongbin16",
        repo = "gitlinker.nvim.git",
        rev = "399b1d05473c711fc5592a6ffc724e231c403486",
        file = "lua/gitlinker/logger.lua",
        lstart = 1,
        lend = 1,
        file_changed = false,
      }--[[@as gitlinker.Linker]]
      local actual = gitlinker._browse(lk)
      assert_eq(
        actual,
        "https://bitbucket.org/linrongbin16/gitlinker.nvim/src/399b1d05473c711fc5592a6ffc724e231c403486/lua/gitlinker/logger.lua#lines-1"
      )
      assert_eq(actual, routers.bitbucket_browse(lk))
    end)
    it("bitbucket with different line start and line end", function()
      local lk = {
        remote_url = "https://bitbucket.org/linrongbin16/gitlinker.nvim.git",
        protocol = "https://",
        host = "bitbucket.org",
        user = "linrongbin16",
        repo = "gitlinker.nvim.git",
        rev = "399b1d05473c711fc5592a6ffc724e231c403486",
        file = "lua/gitlinker/logger.lua",
        lstart = 27,
        lend = 51,
        file_changed = false,
      }--[[@as gitlinker.Linker]]
      local actual = gitlinker._browse(lk)
      assert_eq(
        actual,
        "https://bitbucket.org/linrongbin16/gitlinker.nvim/src/399b1d05473c711fc5592a6ffc724e231c403486/lua/gitlinker/logger.lua#lines-27:51"
      )
      assert_eq(actual, routers.bitbucket_browse(lk))
    end)
    it("codeberg with same line start and line end", function()
      local lk = {
        remote_url = "git@codeberg.org:linrongbin16/gitlinker.nvim.git",
        protocol = "git@",
        host = "codeberg.org",
        user = "linrongbin16",
        repo = "gitlinker.nvim.git",
        rev = "399b1d05473c711fc5592a6ffc724e231c403486",
        file = "lua/gitlinker/logger.lua",
        lstart = 17,
        lend = 17,
        file_changed = false,
      }--[[@as gitlinker.Linker]]
      local actual = gitlinker._browse(lk)
      assert_eq(
        actual,
        "https://codeberg.org/linrongbin16/gitlinker.nvim/src/commit/399b1d05473c711fc5592a6ffc724e231c403486/lua/gitlinker/logger.lua?display=source#L17"
      )
      assert_eq(actual, routers.codeberg_browse(lk))
    end)
    it("codeberg with different line start and line end", function()
      local lk = {
        remote_url = "https://codeberg.org/linrongbin16/gitlinker.nvim.git",
        protocol = "https://",
        host = "codeberg.org",
        user = "linrongbin16",
        repo = "gitlinker.nvim.git",
        rev = "399b1d05473c711fc5592a6ffc724e231c403486",
        file = "lua/gitlinker/logger.lua",
        lstart = 27,
        lend = 53,
        file_changed = false,
      }--[[@as gitlinker.Linker]]
      local actual = gitlinker._browse(lk)
      assert_eq(
        actual,
        "https://codeberg.org/linrongbin16/gitlinker.nvim/src/commit/399b1d05473c711fc5592a6ffc724e231c403486/lua/gitlinker/logger.lua?display=source#L27-L53"
      )
      assert_eq(actual, routers.codeberg_browse(lk))
    end)
  end)
  describe("[_blame]", function()
    it("github with same lstart/lend", function()
      local lk = {
        remote_url = "git@github.com:linrongbin16/gitlinker.nvim.git",
        protocol = "git@",
        host = "github.com",
        user = "linrongbin16",
        repo = "gitlinker.nvim.git",
        rev = "399b1d05473c711fc5592a6ffc724e231c403486",
        file = "lua/gitlinker/logger.lua",
        file_changed = false,
        lstart = 1,
        lend = 1,
      } --[[@as gitlinker.Linker]]
      local actual = gitlinker._blame(lk)
      assert_eq(
        actual,
        "https://github.com/linrongbin16/gitlinker.nvim/blame/399b1d05473c711fc5592a6ffc724e231c403486/lua/gitlinker/logger.lua?plain=1#L1"
      )
      assert_eq(actual, routers.github_blame(lk))
    end)
    it("github with different lstart/lend", function()
      local lk = {
        remote_url = "https://github.com:linrongbin16/gitlinker.nvim.git",
        protocol = "https://",
        host = "github.com",
        user = "linrongbin16",
        repo = "gitlinker.nvim.git",
        rev = "399b1d05473c711fc5592a6ffc724e231c403486",
        file = "lua/gitlinker/logger.lua",
        lstart = 1,
        lend = 2,
        file_changed = false,
      }--[[@as gitlinker.Linker]]
      local actual = gitlinker._blame(lk)
      assert_eq(
        actual,
        "https://github.com/linrongbin16/gitlinker.nvim/blame/399b1d05473c711fc5592a6ffc724e231c403486/lua/gitlinker/logger.lua?plain=1#L1-L2"
      )
      assert_eq(actual, routers.github_blame(lk))
    end)
    it("gitlab with same lstart/lend", function()
      local lk = {
        remote_url = "git@gitlab.com:linrongbin16/gitlinker.nvim.git",
        protocol = "git@",
        host = "gitlab.com",
        user = "linrongbin16",
        repo = "gitlinker.nvim.git",
        rev = "399b1d05473c711fc5592a6ffc724e231c403486",
        file = "lua/gitlinker/logger.lua",
        file_changed = false,
        lstart = 1,
        lend = 1,
      } --[[@as gitlinker.Linker]]
      local actual = gitlinker._blame(lk)
      assert_eq(
        actual,
        "https://gitlab.com/linrongbin16/gitlinker.nvim/blame/399b1d05473c711fc5592a6ffc724e231c403486/lua/gitlinker/logger.lua#L1"
      )
      assert_eq(actual, routers.gitlab_blame(lk))
    end)
    it("gitlab with different lstart/lend", function()
      local lk = {
        remote_url = "https://gitlab.com:linrongbin16/gitlinker.nvim.git",
        protocol = "https://",
        host = "gitlab.com",
        user = "linrongbin16",
        repo = "gitlinker.nvim.git",
        rev = "399b1d05473c711fc5592a6ffc724e231c403486",
        file = "lua/gitlinker/logger.lua",
        lstart = 1,
        lend = 2,
        file_changed = false,
      }--[[@as gitlinker.Linker]]
      local actual = gitlinker._blame(lk)
      assert_eq(
        actual,
        "https://gitlab.com/linrongbin16/gitlinker.nvim/blame/399b1d05473c711fc5592a6ffc724e231c403486/lua/gitlinker/logger.lua#L1-L2"
      )
      assert_eq(actual, routers.gitlab_blame(lk))
    end)
    it("bitbucket with same lstart/lend", function()
      local lk = {
        remote_url = "git@bitbucket.org:linrongbin16/gitlinker.nvim.git",
        protocol = "git@",
        host = "bitbucket.org",
        user = "linrongbin16",
        repo = "gitlinker.nvim.git",
        rev = "399b1d05473c711fc5592a6ffc724e231c403486",
        file = "lua/gitlinker/logger.lua",
        file_changed = false,
        lstart = 13,
        lend = 13,
      } --[[@as gitlinker.Linker]]
      local actual = gitlinker._blame(lk)
      assert_eq(
        actual,
        "https://bitbucket.org/linrongbin16/gitlinker.nvim/annotate/399b1d05473c711fc5592a6ffc724e231c403486/lua/gitlinker/logger.lua#lines-13"
      )
      assert_eq(actual, routers.bitbucket_blame(lk))
    end)
    it("bitbucket with different lstart/lend", function()
      local lk = {
        remote_url = "https://bitbucket.org:linrongbin16/gitlinker.nvim.git",
        protocol = "https://",
        host = "bitbucket.org",
        user = "linrongbin16",
        repo = "gitlinker.nvim.git",
        rev = "399b1d05473c711fc5592a6ffc724e231c403486",
        file = "lua/gitlinker/logger.lua",
        lstart = 1,
        lend = 2,
        file_changed = false,
      }--[[@as gitlinker.Linker]]
      local actual = gitlinker._blame(lk)
      assert_eq(
        actual,
        "https://bitbucket.org/linrongbin16/gitlinker.nvim/annotate/399b1d05473c711fc5592a6ffc724e231c403486/lua/gitlinker/logger.lua#lines-1:2"
      )
      assert_eq(actual, routers.bitbucket_blame(lk))
    end)
    it("codeberg with same lstart/lend", function()
      local lk = {
        remote_url = "git@codeberg.org:linrongbin16/gitlinker.nvim.git",
        protocol = "git@",
        host = "codeberg.org",
        user = "linrongbin16",
        repo = "gitlinker.nvim.git",
        rev = "399b1d05473c711fc5592a6ffc724e231c403486",
        file = "lua/gitlinker/logger.lua",
        file_changed = false,
        lstart = 13,
        lend = 13,
      } --[[@as gitlinker.Linker]]
      local actual = gitlinker._blame(lk)
      assert_eq(
        actual,
        "https://codeberg.org/linrongbin16/gitlinker.nvim/blame/commit/399b1d05473c711fc5592a6ffc724e231c403486/lua/gitlinker/logger.lua?display=source#L13"
      )
      assert_eq(actual, routers.codeberg_blame(lk))
    end)
    it("codeberg with different lstart/lend", function()
      local lk = {
        remote_url = "https://codeberg.org:linrongbin16/gitlinker.nvim.git",
        protocol = "https://",
        host = "codeberg.org",
        host_delimiter = ":",
        user = "linrongbin16",
        repo = "gitlinker.nvim.git",
        rev = "399b1d05473c711fc5592a6ffc724e231c403486",
        file = "lua/gitlinker/logger.lua",
        lstart = 13,
        lend = 21,
        file_changed = false,
      }--[[@as gitlinker.Linker]]
      local actual = gitlinker._blame(lk)
      assert_eq(
        actual,
        "https://codeberg.org/linrongbin16/gitlinker.nvim/blame/commit/399b1d05473c711fc5592a6ffc724e231c403486/lua/gitlinker/logger.lua?display=source#L13-L21"
      )
      assert_eq(actual, routers.codeberg_blame(lk))
    end)
  end)
  describe("[_make_resolved_remote_url]", function()
    it("resolve /", function()
      local lk = {
        remote_url = "https://codeberg.org/linrongbin16/gitlinker.nvim.git",
        protocol = "https://",
        host = "my-personal-codeberg.org",
        host_delimiter = "/",
        user = "linrongbin16",
        repo = "gitlinker.nvim.git",
        rev = "399b1d05473c711fc5592a6ffc724e231c403486",
        file = "lua/gitlinker/logger.lua",
        lstart = 13,
        lend = 21,
        file_changed = false,
      }--[[@as gitlinker.Linker]]
      local actual = gitlinker._make_resolved_remote_url(lk)
      assert_eq(
        actual,
        "https://my-personal-codeberg.org/linrongbin16/gitlinker.nvim.git"
      )
    end)
    it("resolve :", function()
      local lk = {
        remote_url = "git@codeberg.org:linrongbin16/gitlinker.nvim.git",
        protocol = "git@",
        host = "my-personal-codeberg.org",
        host_delimiter = ":",
        user = "linrongbin16",
        repo = "gitlinker.nvim.git",
        rev = "399b1d05473c711fc5592a6ffc724e231c403486",
        file = "lua/gitlinker/logger.lua",
        lstart = 13,
        lend = 21,
        file_changed = false,
      }--[[@as gitlinker.Linker]]
      local actual = gitlinker._make_resolved_remote_url(lk)
      assert_eq(
        actual,
        "git@my-personal-codeberg.org:linrongbin16/gitlinker.nvim.git"
      )
    end)
  end)
  describe("[_worker]", function()
    it("is function", function()
      local lk = {
        remote_url = "git@codeberg.org:linrongbin16/gitlinker.nvim.git",
        protocol = "git@",
        host = "my-personal-codeberg.org",
        host_delimiter = ":",
        user = "linrongbin16",
        repo = "gitlinker.nvim.git",
        rev = "399b1d05473c711fc5592a6ffc724e231c403486",
        file = "lua/gitlinker/logger.lua",
        lstart = 13,
        lend = 21,
        file_changed = false,
      }--[[@as gitlinker.Linker]]
      local actual = gitlinker._worker(lk, "pattern", function(lk1)
        assert_true(vim.deep_equal(lk, lk1))
        return 1
      end)
      assert_eq(actual, 1)
    end)
    it("is string", function()
      local lk = {
        remote_url = "git@codeberg.org:linrongbin16/gitlinker.nvim.git",
        protocol = "git@",
        host = "my-personal-codeberg.org",
        host_delimiter = ":",
        user = "linrongbin16",
        repo = "gitlinker.nvim.git",
        rev = "399b1d05473c711fc5592a6ffc724e231c403486",
        file = "lua/gitlinker/logger.lua",
        lstart = 13,
        lend = 21,
        file_changed = false,
      }--[[@as gitlinker.Linker]]
      local string_template = "https://codeberg.org/"
        .. "{_A.USER}/"
        .. "{_A.REPO}/blame/commit/"
        .. "{_A.REV}/"
        .. "{_A.FILE}"
        .. "#L{_A.LSTART}"
        .. "{(_A.LEND > _A.LSTART and ('-L' .. _A.LEND) or '')}"
      local actual = gitlinker._worker(lk, "pattern", string_template)
      assert_eq(
        actual,
        "https://codeberg.org/linrongbin16/gitlinker.nvim/blame/commit/399b1d05473c711fc5592a6ffc724e231c403486/lua/gitlinker/logger.lua#L13-L21"
      )
    end)
  end)
  describe("[_merge_routers]", function()
    it("test map bindings", function()
      local actual = gitlinker._merge_routers({
        router = {
          browse = {
            ["^git%.xyz%.com"] = "https://git.xyz.com/browse",
          },
          blame = {
            ["^git%.xyz%.com"] = "https://git.xyz.com/blame",
          },
        },
      })

      print(string.format("merged routers:%s\n", vim.inspect(actual)))
      local browse_list = actual.browse.list_routers
      local browse_map = actual.browse.map_routers
      local blame_list = actual.blame.list_routers
      local blame_map = actual.blame.map_routers

      assert_eq(#browse_list, 0)
      do
        local browse_n = 0
        for k, v in pairs(browse_map) do
          if k == "^github%.com" then
            browse_n = browse_n + 1
          elseif k == "^gitlab%.com" then
            browse_n = browse_n + 1
          elseif k == "^bitbucket%.org" then
            browse_n = browse_n + 1
          elseif k == "^codeberg%.org" then
            browse_n = browse_n + 1
          elseif k == "^git%.samba%.org" then
            browse_n = browse_n + 1
          elseif k == "^git%.xyz%.com" then
            assert_eq(v, "https://git.xyz.com/browse")
            browse_n = browse_n + 1
          end
        end
        assert_eq(browse_n, 6)
      end

      assert_eq(#blame_list, 0)
      do
        local blame_n = 0
        for k, v in pairs(blame_map) do
          if k == "^github%.com" then
            blame_n = blame_n + 1
          elseif k == "^gitlab%.com" then
            blame_n = blame_n + 1
          elseif k == "^bitbucket%.org" then
            blame_n = blame_n + 1
          elseif k == "^codeberg%.org" then
            blame_n = blame_n + 1
          elseif k == "^git%.xyz%.com" then
            assert_eq(v, "https://git.xyz.com/blame")
            blame_n = blame_n + 1
          end
        end
        assert_eq(blame_n, 5)
      end
    end)
    it("test list bindings", function()
      local actual = gitlinker._merge_routers({
        router = {
          browse = {
            {
              "^https://git%.xyz%.com/linrongbin16/gitlinker.nvim",
              "https://git.xyz.com/linrongbin16/gitlinker.nvim/browse",
            },
            { "^git%.xyz%.com", "https://git.xyz.com/browse" },
          },
          blame = {
            {
              "^https://git%.xyz%.com/linrongbin16/gitlinker.nvim",
              "https://git.xyz.com/linrongbin16/gitlinker.nvim/blame",
            },
            { "^git%.xyz%.com", "https://git.xyz.com/blame" },
          },
        },
      })

      local browse_list = actual.browse.list_routers
      local browse_map = actual.browse.map_routers
      local blame_list = actual.blame.list_routers
      local blame_map = actual.blame.map_routers

      assert_eq(#browse_list, 2)
      do
        local browse_m = 0
        for _, tuple in ipairs(browse_list) do
          local p = tuple[1]
          local r = tuple[2]
          if p == "^https://git%.xyz%.com/linrongbin16/gitlinker.nvim" then
            assert_eq(
              r,
              "https://git.xyz.com/linrongbin16/gitlinker.nvim/browse"
            )
            browse_m = browse_m + 1
          elseif p == "^git%.xyz%.com" then
            assert_eq(r, "https://git.xyz.com/browse")
            browse_m = browse_m + 1
          end
        end
        assert_eq(browse_m, 2)
      end

      do
        local browse_n = 0
        for k, v in pairs(browse_map) do
          if k == "^github%.com" then
            browse_n = browse_n + 1
          elseif k == "^gitlab%.com" then
            browse_n = browse_n + 1
          elseif k == "^bitbucket%.org" then
            browse_n = browse_n + 1
          elseif k == "^codeberg%.org" then
            browse_n = browse_n + 1
          elseif k == "^git%.samba%.org" then
            browse_n = browse_n + 1
          end
        end
        assert_eq(browse_n, 5)
      end

      assert_eq(#blame_list, 2)
      do
        local blame_m = 0
        for _, tuple in ipairs(blame_list) do
          local p = tuple[1]
          local r = tuple[2]
          if p == "^https://git%.xyz%.com/linrongbin16/gitlinker.nvim" then
            assert_eq(
              r,
              "https://git.xyz.com/linrongbin16/gitlinker.nvim/blame"
            )
            blame_m = blame_m + 1
          elseif p == "^git%.xyz%.com" then
            assert_eq(r, "https://git.xyz.com/blame")
            blame_m = blame_m + 1
          end
        end
        assert_eq(blame_m, 2)
      end

      do
        local blame_n = 0
        for k, v in pairs(blame_map) do
          if k == "^github%.com" then
            blame_n = blame_n + 1
          elseif k == "^gitlab%.com" then
            blame_n = blame_n + 1
          elseif k == "^bitbucket%.org" then
            blame_n = blame_n + 1
          elseif k == "^codeberg%.org" then
            blame_n = blame_n + 1
          end
        end
        assert_eq(blame_n, 4)
      end
    end)
  end)
  describe("[user router types]", function()
    it("default_branch", function()
      local lk = {
        remote_url = "https://github.com/linrongbin16/gitlinker.nvim.git",
        protocol = "https://",
        host = "github.com",
        host_delimiter = "/",
        user = "linrongbin16",
        repo = "gitlinker.nvim.git",
        rev = "399b1d05473c711fc5592a6ffc724e231c403486",
        file = "lua/gitlinker/logger.lua",
        lstart = 13,
        lend = 21,
        file_changed = false,
        default_branch = "master",
        current_branch = "test",
      }--[[@as gitlinker.Linker]]
      local actual = gitlinker._router("default_branch", lk)
      assert_eq(
        actual,
        "https://github.com/linrongbin16/gitlinker.nvim/blob/master/lua/gitlinker/logger.lua?plain=1#L13-L21"
      )
    end)
    it("current_branch", function()
      local lk = {
        remote_url = "https://github.com/linrongbin16/gitlinker.nvim.git",
        protocol = "https://",
        host = "github.com",
        host_delimiter = "/",
        user = "linrongbin16",
        repo = "gitlinker.nvim.git",
        rev = "399b1d05473c711fc5592a6ffc724e231c403486",
        file = "lua/gitlinker/logger.lua",
        lstart = 13,
        lend = 21,
        file_changed = false,
        default_branch = "master",
        current_branch = "current",
      }--[[@as gitlinker.Linker]]
      local actual = gitlinker._router("current_branch", lk)
      assert_eq(
        actual,
        "https://github.com/linrongbin16/gitlinker.nvim/blob/current/lua/gitlinker/logger.lua?plain=1#L13-L21"
      )
    end)
  end)
end)
