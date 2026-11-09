local cwd = vim.fn.getcwd()

describe("gitlinker", function()
  local assert_eq = assert.is_equal
  local assert_true = assert.is_true
  local assert_false = assert.is_false

  before_each(function()
    vim.api.nvim_command("cd " .. cwd)
    vim.opt.swapfile = false
    vim.cmd([[edit lua/gitlinker.lua]])
  end)

  local gitlinker = require("gitlinker")
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

  describe("[_url_template_engine]", function()
    it("test nil parameters", function()
      assert_eq(gitlinker._url_template_engine(nil, "asdfasdf"), nil)
      assert_eq(gitlinker._url_template_engine({}, nil), nil)
      assert_eq(gitlinker._url_template_engine({}, ""), nil)
    end)
    it("test-1", function()
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
      local actual = gitlinker._url_template_engine(lk, "https://{_A.HOST}")
      print(string.format("_url_template_engine-1:%s\n", vim.inspect(actual)))
      assert_eq(actual, "https://git.samba.org")
    end)
    it("test-2", function()
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
      local actual = gitlinker._url_template_engine(lk, "https://samba.git")
      print(string.format("_url_template_engine-2:%s\n", vim.inspect(actual)))
      assert_eq(actual, "https://samba.git")
    end)
  end)
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
    end)
    it("git.samba.org/samba.git with different lstart/lend", function()
      local lk = {
        remote_url = "https://git.samba.org/samba.git",
        protocol = "https",
        username = nil,
        password = nil,
        host = "git.samba.org",
        org = "",
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
    end)
    it("git.samba.org/bbaumbach/samba.git with same lstart/lend", function()
      local lk = {
        remote_url = "git@git.samba.org:bbaumbach/samba.git",
        protocol = nil,
        username = "git",
        password = nil,
        host = "git.samba.org",
        org = "bbaumbach",
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
    end)
    it("git.samba.org/bbaumbach/samba.git with different lstart/lend", function()
      local lk = {
        remote_url = "https://git.samba.org/bbaumbach/samba.git",
        protocol = "https",
        username = nil,
        password = nil,
        host = "git.samba.org",
        org = "bbaumbach",
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
    end)
    it("github with same lstart/lend", function()
      local lk = {
        remote_url = "git@github.com:linrongbin16/gitlinker.nvim.git",
        protocol = nil,
        username = "git",
        password = nil,
        host = "github.com",
        org = "linrongbin16",
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
    end)
    it("github with different lstart/lend", function()
      local lk = {
        remote_url = "git@github.com:linrongbin16/gitlinker.nvim.git",
        username = "git",
        host = "github.com",
        org = "linrongbin16",
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
    end)
    it("ssh://git@github.com:/myorg/myrepo.git", function()
      local lk = {
        remote_url = "ssh://git@github.com:/myorg/myrepo.git",
        username = "git",
        host = "github.com",
        org = "myorg",
        repo = "myrepo.git",
        rev = "399b1d05473c711fc5592a6ffc724e231c403486",
        file = "lua/gitlinker/logger.lua",
        lstart = 1,
        lend = 1,
        file_changed = false,
      }--[[@as gitlinker.Linker]]
      local actual = gitlinker._browse(lk)
      assert_eq(
        actual,
        "https://github.com/myorg/myrepo/blob/399b1d05473c711fc5592a6ffc724e231c403486/lua/gitlinker/logger.lua?plain=1#L1"
      )
    end)
    it("ssh://git@git.xyz.com with same lstart/lend", function()
      local lk = {
        remote_url = "ssh://git@git.xyz.com/linrongbin16/gitlinker.nvim.git",
        protocol = "ssh",
        username = "git",
        host = "git.xyz.com",
        user = "linrongbin16",
        org = "linrongbin16",
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
    end)
    it("ssh://git@git.xyz.com with different lstart/lend", function()
      local lk = {
        remote_url = "ssh://git@github.com:linrongbin16/gitlinker.nvim.git",
        protocol = "ssh",
        username = "git",
        host = "git.xyz.com",
        org = "linrongbin16",
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
    end)
    it("gitlab with same line start and line end", function()
      local lk = {
        remote_url = "https://gitlab.com/linrongbin16/gitlinker.nvim.git",
        protocol = "https",
        host = "gitlab.com",
        org = "linrongbin16",
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
    end)
    it("gitlab with different line start and line end", function()
      local lk = {
        remote_url = "git@gitlab.com:linrongbin16/gitlinker.nvim.git",
        username = "git",
        host = "gitlab.com",
        org = "linrongbin16",
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
    end)
    it("bitbucket with same line start and line end", function()
      local lk = {
        remote_url = "git@bitbucket.org:linrongbin16/gitlinker.nvim.git",
        username = "git",
        host = "bitbucket.org",
        org = "linrongbin16",
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
    end)
    it("bitbucket with different line start and line end", function()
      local lk = {
        remote_url = "https://bitbucket.org/linrongbin16/gitlinker.nvim.git",
        protocol = "https",
        host = "bitbucket.org",
        org = "linrongbin16",
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
    end)
    it("codeberg with same line start and line end", function()
      local lk = {
        remote_url = "git@codeberg.org:linrongbin16/gitlinker.nvim.git",
        username = "git",
        host = "codeberg.org",
        org = "linrongbin16",
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
    end)
    it("codeberg with different line start and line end", function()
      local lk = {
        remote_url = "https://codeberg.org/linrongbin16/gitlinker.nvim.git",
        protocol = "https",
        host = "codeberg.org",
        org = "linrongbin16",
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
    end)
  end)
  describe("[_blame]", function()
    it("github with same lstart/lend", function()
      local lk = {
        remote_url = "git@github.com:linrongbin16/gitlinker.nvim.git",
        username = "git",
        host = "github.com",
        org = "linrongbin16",
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
    end)
    it("github with different lstart/lend", function()
      local lk = {
        remote_url = "https://github.com:linrongbin16/gitlinker.nvim.git",
        protocol = "https",
        host = "github.com",
        org = "linrongbin16",
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
    end)
    it("gitlab with same lstart/lend", function()
      local lk = {
        remote_url = "git@gitlab.com:linrongbin16/gitlinker.nvim.git",
        username = "git",
        host = "gitlab.com",
        org = "linrongbin16",
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
    end)
    it("gitlab with different lstart/lend", function()
      local lk = {
        remote_url = "https://gitlab.com:linrongbin16/gitlinker.nvim.git",
        protocol = "https",
        host = "gitlab.com",
        org = "linrongbin16",
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
    end)
    it("bitbucket with same lstart/lend", function()
      local lk = {
        remote_url = "git@bitbucket.org:linrongbin16/gitlinker.nvim.git",
        username = "git",
        host = "bitbucket.org",
        org = "linrongbin16",
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
    end)
    it("bitbucket with different lstart/lend", function()
      local lk = {
        remote_url = "https://bitbucket.org:linrongbin16/gitlinker.nvim.git",
        protocol = "https",
        host = "bitbucket.org",
        org = "linrongbin16",
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
    end)
    it("codeberg with same lstart/lend", function()
      local lk = {
        remote_url = "git@codeberg.org:linrongbin16/gitlinker.nvim.git",
        username = "git",
        host = "codeberg.org",
        org = "linrongbin16",
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
    end)
    it("codeberg with different lstart/lend", function()
      local lk = {
        remote_url = "https://codeberg.org:linrongbin16/gitlinker.nvim.git",
        protocol = "https",
        host = "codeberg.org",
        org = "linrongbin16",
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
    end)
  end)
  describe("[_worker]", function()
    it("is function", function()
      local lk = {
        remote_url = "git@codeberg.org:linrongbin16/gitlinker.nvim.git",
        username = "git",
        host = "my-personal-codeberg.org",
        org = "linrongbin16",
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
        username = "git",
        host = "my-personal-codeberg.org",
        org = "linrongbin16",
        repo = "gitlinker.nvim.git",
        rev = "399b1d05473c711fc5592a6ffc724e231c403486",
        file = "lua/gitlinker/logger.lua",
        lstart = 13,
        lend = 21,
        file_changed = false,
      }--[[@as gitlinker.Linker]]
      local string_template = "https://codeberg.org/"
        .. "{_A.ORG}/"
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
    it("is invalid", function()
      local lk = {
        remote_url = "git@codeberg.org:linrongbin16/gitlinker.nvim.git",
        username = "git",
        host = "my-personal-codeberg.org",
        org = "linrongbin16",
        repo = "gitlinker.nvim.git",
        rev = "399b1d05473c711fc5592a6ffc724e231c403486",
        file = "lua/gitlinker/logger.lua",
        lstart = 13,
        lend = 21,
        file_changed = false,
      }--[[@as gitlinker.Linker]]
      local string_template = "https://codeberg.org/"
        .. "{_A.ORG}/"
        .. "{_A.REPO}/blame/commit/"
        .. "{_A.REV}/"
        .. "{_A.FILE}"
        .. "#L{_A.LSTART}"
        .. "{(_A.LEND > _A.LSTART and ('-L' .. _A.LEND) or '')}"
      local ok, actual = pcall(gitlinker._worker, lk, "pattern", { string_template })
      assert_false(ok)
      assert_eq(type(actual), "string")
    end)
  end)
  describe("[user router types]", function()
    it("default_branch", function()
      local lk = {
        remote_url = "https://github.com/linrongbin16/gitlinker.nvim.git",
        protocol = "https",
        host = "github.com",
        org = "linrongbin16",
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
        protocol = "https",
        host = "github.com",
        org = "linrongbin16",
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

  describe("[_void_link]", function()
    it("link browse", function()
      gitlinker._void_link({
        action = require("gitlinker.actions").clipboard,
        router = function(lk)
          return require("gitlinker")._router("browse", lk)
        end,
        lstart = 1,
        lend = 1,
      })
    end)
    it("link blame", function()
      gitlinker._void_link({
        action = require("gitlinker.actions").clipboard,
        router = function(lk)
          return require("gitlinker")._router("blame", lk)
        end,
        lstart = 1,
        lend = 1,
      })
    end)
  end)

  describe("[command range]", function()
    -- `:1,3GitLink` used to be unioned with the cursor line, so running it from
    -- line 15 linked lines 1 to 15. These cases capture the url through
    -- `clipboard_override` and read the line anchor back out of it.
    local repo
    local saved_override

    --- Run `args` and fail loudly when it exits non-zero: a silently broken
    --- fixture would otherwise surface as a confusing assertion error later.
    --- @param args string[]
    local function sh(args)
      local out = vim.fn.system(args)
      assert_eq(vim.v.shell_error, 0, string.format("%s => %s", table.concat(args, " "), out))
    end

    --- Run `run`, which receives a callback to deliver the url to, and return
    --- the url it produced.
    --- @param run fun(collect: fun(url:string))
    --- @return string?
    local function url_of(run)
      local url
      run(function(u)
        url = u
      end)
      vim.wait(5000, function()
        return url ~= nil
      end, 10)
      -- The url arrives from inside the async task, which keeps going for a
      -- few more scheduled steps. Let it finish before the fixture is torn
      -- down, or the leftover step reads a buffer that no longer belongs to
      -- this repository and logs a fatal of its own.
      vim.wait(300)
      return url
    end

    --- Run the `:GitLink` command and return the url it copies out.
    --- @param run fun()
    --- @return string?
    local function command_url_of(run)
      return url_of(function(collect)
        local confs = require("gitlinker.configs").get()
        confs.clipboard_override = collect
        run()
        confs.clipboard_override = saved_override
      end)
    end

    --- Run the `:GitLink` command and return the line anchor of its url.
    --- @param run fun()
    --- @return string?
    local function anchor_of(run)
      local url = command_url_of(run)
      return url and url:match("#L[%dL%-]*$") or nil
    end

    before_each(function()
      -- Earlier describes start tasks they never join. Give them a few turns
      -- to finish before this block switches the current buffer out from under
      -- them, which would make their path lookup fail and log a fatal.
      vim.wait(300)
      repo = vim.fn.tempname()
      vim.fn.mkdir(repo, "p")
      local lines = {}
      for i = 1, 20 do
        lines[i] = "line " .. i
      end
      vim.fn.writefile(lines, repo .. "/demo.txt")
      vim.fn.mkdir(repo .. "/some dir", "p")
      vim.fn.writefile({ "spaced" }, repo .. "/some dir/a b.lua")

      sh({ "git", "init", "--quiet", "-b", "main", repo })
      sh({ "git", "-C", repo, "config", "user.email", "test@example.com" })
      sh({ "git", "-C", repo, "config", "user.name", "test" })
      sh({ "git", "-C", repo, "config", "commit.gpgsign", "false" })
      sh({ "git", "-C", repo, "add", "--all" })
      sh({ "git", "-C", repo, "commit", "--quiet", "--message", "init" })
      sh({ "git", "-C", repo, "remote", "add", "origin", "https://github.com/acme/demo.git" })
      sh({ "git", "-C", repo, "update-ref", "refs/remotes/origin/main", "HEAD" })
      sh({
        "git",
        "-C",
        repo,
        "symbolic-ref",
        "refs/remotes/origin/HEAD",
        "refs/remotes/origin/main",
      })
      sh({ "git", "-C", repo, "branch", "--set-upstream-to=origin/main", "main" })

      vim.cmd("edit! " .. vim.fn.fnameescape(repo .. "/demo.txt"))
      saved_override = require("gitlinker.configs").get().clipboard_override
    end)

    after_each(function()
      -- Let the task started by `GitLink` run to the end while its buffer is
      -- still around: it only reaches its last steps after a few scheduled
      -- turns, and tearing the fixture down early makes those steps read a
      -- buffer that belongs to no repository any more.
      vim.wait(300)
      require("gitlinker.configs").get().clipboard_override = saved_override
      vim.cmd("silent! enew!")
      vim.fn.delete(repo, "rf")
    end)

    it("links the cursor line when no range is given", function()
      vim.api.nvim_win_set_cursor(0, { 15, 0 })
      assert_eq(
        anchor_of(function()
          vim.cmd("GitLink")
        end),
        "#L15"
      )
    end)

    it("links the range given on the command line", function()
      vim.api.nvim_win_set_cursor(0, { 15, 0 })
      assert_eq(
        anchor_of(function()
          vim.cmd("1,3GitLink")
        end),
        "#L1-L3",
        "cursor line 15 must not join the range"
      )
    end)

    it("links a single line range given on the command line", function()
      vim.api.nvim_win_set_cursor(0, { 15, 0 })
      assert_eq(
        anchor_of(function()
          vim.cmd("2GitLink")
        end),
        "#L2"
      )
    end)

    it("links the whole file given a percent range", function()
      vim.api.nvim_win_set_cursor(0, { 15, 0 })
      assert_eq(
        anchor_of(function()
          vim.cmd("%GitLink")
        end),
        "#L1-L20"
      )
    end)

    it("links the visual selection when it is mapped through <cmd>", function()
      -- The mapping in the readme runs `<cmd>GitLink<cr>` in visual mode, so
      -- the command gets no range: the selection has to be recovered from the
      -- marks instead.
      vim.api.nvim_win_set_cursor(0, { 4, 0 })
      local anchor = anchor_of(function()
        vim.api.nvim_feedkeys(
          vim.api.nvim_replace_termcodes("Vjj<Cmd>GitLink<CR>", true, false, true),
          "x",
          false
        )
      end)
      assert_eq(anchor, "#L4-L6")
    end)

    it("uri-encodes a quoted file path that contains spaces", function()
      local url = command_url_of(function()
        vim.cmd([[GitLink file="some dir/a b.lua"]])
      end)
      assert_true(
        url ~= nil and url:find("some%20dir/a%20b.lua", 1, true) ~= nil,
        string.format("url: %s", vim.inspect(url))
      )
    end)

    it("uri-encodes an escaped file path that contains spaces", function()
      local url = command_url_of(function()
        vim.cmd([[GitLink file=some\ dir/a\ b.lua]])
      end)
      assert_true(
        url ~= nil and url:find("some%20dir/a%20b.lua", 1, true) ~= nil,
        string.format("url: %s", vim.inspect(url))
      )
    end)
  end)

  describe("[link]", function()
    it("browse", function()
      gitlinker.link()
      gitlinker.link({})
      gitlinker.link({
        action = function(url)
          print(string.format("link-browse-1:%s\n", vim.inspect(url)))
        end,
      })
    end)
    it("blame", function()
      gitlinker.link({ router_type = "blame" })
    end)
    it("default_branch", function()
      gitlinker.link({ router_type = "default_branch" })
    end)
    it("does not mutate the options table it is handed", function()
      -- A keymap closure hands the same table to every press, so resolving the
      -- line range into it would freeze the range of the first press.
      local opts = { router_type = "blame" }
      gitlinker.link(opts)
      assert_eq(opts.router_type, "blame")
      assert_eq(opts.action, nil)
      assert_eq(opts.router, nil)
      assert_eq(opts.lstart, nil)
      assert_eq(opts.lend, nil)
    end)

    --- Link with `opts` and return the urls the action received together with
    --- the error messages logged along the way.
    ---
    --- `log.err()` notifies from a scheduled callback, so the loop has to run
    --- once before the messages can be read back.
    --- @param opts table
    --- @return string[] urls, string[] errors
    local function link_and_capture(opts)
      local urls, errors = {}, {}
      local notify = vim.notify
      vim.notify = function(msg, level)
        if level == vim.log.levels.ERROR then
          table.insert(errors, msg)
        end
      end
      opts.action = function(url)
        table.insert(urls, url)
      end
      local ok, err = pcall(gitlinker.link, opts)
      vim.wait(300)
      vim.notify = notify
      assert_true(ok, err)
      return urls, errors
    end

    it("links a single line when the caller names only one end", function()
      -- A half-given range used to reach `luaeval` as `vim.NIL`, which the
      -- default templates compared with a number and raised from inside the
      -- template. The other end is now filled in from the one that was given.
      local urls, errors = link_and_capture({ lend = 6 })
      assert_eq(#errors, 0, string.format("errors: %s", vim.inspect(errors)))
      assert_eq(#urls, 1)
      assert_eq(urls[1]:match("#L[%dL%-]*$"), "#L6")
    end)

    it("links the same single line for the other end", function()
      local urls, errors = link_and_capture({ lstart = 6 })
      assert_eq(#errors, 0, string.format("errors: %s", vim.inspect(errors)))
      assert_eq(#urls, 1)
      assert_eq(urls[1]:match("#L[%dL%-]*$"), "#L6")
    end)

    it("sorts a reversed range instead of dropping its end", function()
      -- `LEND` used to fall back to `LSTART` here, so the url silently named a
      -- single line instead of the range the caller asked for.
      local urls, errors = link_and_capture({ lstart = 5, lend = 3 })
      assert_eq(#errors, 0, string.format("errors: %s", vim.inspect(errors)))
      assert_eq(#urls, 1)
      assert_eq(urls[1]:match("#L[%dL%-]*$"), "#L3-L5")
    end)

    it("links a single line range given by the caller", function()
      local urls, errors = link_and_capture({ lstart = 2, lend = 2 })
      assert_eq(#errors, 0, string.format("errors: %s", vim.inspect(errors)))
      assert_eq(#urls, 1)
      assert_eq(urls[1]:match("#L[%dL%-]*$"), "#L2")
    end)
  end)
end)
