local cwd = vim.fn.getcwd()

--- The revision the mocked repository resolves to.
local MOCK_REV = "c171bb5f0151963cf7aa9efa151be0182bbea848"

--- Mock `vim.system`, the single API `gitlinker.git` runs every command
--- through, so a case fully controls the stdout/stderr its git calls see.
---
--- `rules` maps a command-line prefix to the answer that command produces:
---
---     mock_vim_system({
---       ["git rev-parse"] = { stdout = { "c171bb5" } },
---       ["git diff"] = { code = 128, stderr = { "fatal: ..." } },
---     })
---
--- The longest matching prefix wins, so `git rev-parse --show-toplevel` can be
--- given its own answer next to a generic `git rev-parse` one. An answer may
--- also be a function receiving the full command, and may carry `spawn_error`
--- to raise the way `vim.system` does when a command cannot be started.
--- @param rules table<string, table|fun(cmd:string[]):table>
--- @return fun()  restores the real API.
local function mock_vim_system(rules)
  local saved = vim.system
  local function answer(cmd)
    local line = table.concat(cmd, " ")
    local best, best_len
    for prefix, rule in pairs(rules) do
      if vim.startswith(line, prefix) and (best_len == nil or #prefix > best_len) then
        best, best_len = rule, #prefix
      end
    end
    if best == nil then
      return { code = 127, stderr = { "fatal: no mock for: " .. line } }
    end
    return type(best) == "function" and best(cmd) or best
  end

  vim.system = function(cmd, _, on_exit)
    local result = answer(cmd)
    if result.spawn_error then
      error(result.spawn_error, 0)
    end
    on_exit({
      code = result.code or 0,
      stdout = table.concat(result.stdout or {}, "\n"),
      stderr = table.concat(result.stderr or {}, "\n"),
    })
    return {}
  end
  return function()
    vim.system = saved
  end
end

describe("gitlinker", function()
  local assert_eq = assert.is_equal
  local assert_true = assert.is_true
  local assert_false = assert.is_false

  local restore_vim_system

  before_each(function()
    vim.api.nvim_command("cd " .. cwd)
    vim.opt.swapfile = false
    vim.cmd([[edit lua/gitlinker.lua]])
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
  end)

  after_each(function()
    -- Join the link tasks a case started before the real API comes back, or a
    -- leftover step would run its git command against the actual repository.
    vim.wait(300)
    if restore_vim_system then
      restore_vim_system()
      restore_vim_system = nil
    end
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
      restore_vim_system = mock_vim_system({
        ["git rev-parse --show-toplevel"] = { stdout = { cwd } },
        ["git rev-parse --abbrev-ref origin/HEAD"] = { stdout = { "origin/main" } },
        ["git rev-parse --abbrev-ref HEAD"] = { stdout = { "main" } },
        ["git rev-parse"] = { stdout = { MOCK_REV } },
        ["git remote get-url origin"] = { stdout = { "https://github.com/acme/demo.git" } },
        ["git remote"] = { stdout = { "origin" } },
        ["git cat-file"] = {}, -- a successful probe prints nothing
        ["git diff"] = {},
        ["ssh -ttG"] = { stdout = { "hostname github.com" } },
      })
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
      restore_vim_system = mock_vim_system({
        ["git rev-parse --show-toplevel"] = { stdout = { cwd } },
        ["git rev-parse --abbrev-ref origin/HEAD"] = { stdout = { "origin/main" } },
        ["git rev-parse --abbrev-ref HEAD"] = { stdout = { "main" } },
        ["git rev-parse"] = { stdout = { MOCK_REV } },
        ["git remote get-url origin"] = { stdout = { "https://github.com/acme/demo.git" } },
        ["git remote"] = { stdout = { "origin" } },
        ["git cat-file"] = {}, -- a successful probe prints nothing
        ["git diff"] = {},
        ["ssh -ttG"] = { stdout = { "hostname github.com" } },
      })
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
    local repo_dir
    local saved_override

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
      repo_dir = vim.fn.tempname()
      vim.fn.mkdir(repo_dir, "p")
      local lines = {}
      for i = 1, 20 do
        lines[i] = "line " .. i
      end
      vim.fn.writefile(lines, repo_dir .. "/demo.txt")
      vim.fn.mkdir(repo_dir .. "/some dir", "p")
      vim.fn.writefile({ "spaced" }, repo_dir .. "/some dir/a b.lua")

      vim.cmd("edit! " .. vim.fn.fnameescape(repo_dir .. "/demo.txt"))
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
      vim.fn.delete(repo_dir, "rf")
    end)

    it("links the cursor line when no range is given", function()
      restore_vim_system = mock_vim_system({
        ["git rev-parse --show-toplevel"] = { stdout = { repo_dir } },
        ["git rev-parse --abbrev-ref origin/HEAD"] = { stdout = { "origin/main" } },
        ["git rev-parse --abbrev-ref HEAD"] = { stdout = { "main" } },
        ["git rev-parse"] = { stdout = { MOCK_REV } },
        ["git remote get-url origin"] = { stdout = { "https://github.com/acme/demo.git" } },
        ["git remote"] = { stdout = { "origin" } },
        ["git cat-file"] = {}, -- a successful probe prints nothing
        ["git diff"] = {},
        ["ssh -ttG"] = { stdout = { "hostname github.com" } },
      })
      vim.api.nvim_win_set_cursor(0, { 15, 0 })
      assert_eq(
        anchor_of(function()
          vim.cmd("GitLink")
        end),
        "#L15"
      )
    end)

    it("links the range given on the command line", function()
      restore_vim_system = mock_vim_system({
        ["git rev-parse --show-toplevel"] = { stdout = { repo_dir } },
        ["git rev-parse --abbrev-ref origin/HEAD"] = { stdout = { "origin/main" } },
        ["git rev-parse --abbrev-ref HEAD"] = { stdout = { "main" } },
        ["git rev-parse"] = { stdout = { MOCK_REV } },
        ["git remote get-url origin"] = { stdout = { "https://github.com/acme/demo.git" } },
        ["git remote"] = { stdout = { "origin" } },
        ["git cat-file"] = {}, -- a successful probe prints nothing
        ["git diff"] = {},
        ["ssh -ttG"] = { stdout = { "hostname github.com" } },
      })
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
      restore_vim_system = mock_vim_system({
        ["git rev-parse --show-toplevel"] = { stdout = { repo_dir } },
        ["git rev-parse --abbrev-ref origin/HEAD"] = { stdout = { "origin/main" } },
        ["git rev-parse --abbrev-ref HEAD"] = { stdout = { "main" } },
        ["git rev-parse"] = { stdout = { MOCK_REV } },
        ["git remote get-url origin"] = { stdout = { "https://github.com/acme/demo.git" } },
        ["git remote"] = { stdout = { "origin" } },
        ["git cat-file"] = {}, -- a successful probe prints nothing
        ["git diff"] = {},
        ["ssh -ttG"] = { stdout = { "hostname github.com" } },
      })
      vim.api.nvim_win_set_cursor(0, { 15, 0 })
      assert_eq(
        anchor_of(function()
          vim.cmd("2GitLink")
        end),
        "#L2"
      )
    end)

    it("links the whole file given a percent range", function()
      restore_vim_system = mock_vim_system({
        ["git rev-parse --show-toplevel"] = { stdout = { repo_dir } },
        ["git rev-parse --abbrev-ref origin/HEAD"] = { stdout = { "origin/main" } },
        ["git rev-parse --abbrev-ref HEAD"] = { stdout = { "main" } },
        ["git rev-parse"] = { stdout = { MOCK_REV } },
        ["git remote get-url origin"] = { stdout = { "https://github.com/acme/demo.git" } },
        ["git remote"] = { stdout = { "origin" } },
        ["git cat-file"] = {}, -- a successful probe prints nothing
        ["git diff"] = {},
        ["ssh -ttG"] = { stdout = { "hostname github.com" } },
      })
      vim.api.nvim_win_set_cursor(0, { 15, 0 })
      assert_eq(
        anchor_of(function()
          vim.cmd("%GitLink")
        end),
        "#L1-L20"
      )
    end)

    it("links the visual selection when it is mapped through <cmd>", function()
      restore_vim_system = mock_vim_system({
        ["git rev-parse --show-toplevel"] = { stdout = { repo_dir } },
        ["git rev-parse --abbrev-ref origin/HEAD"] = { stdout = { "origin/main" } },
        ["git rev-parse --abbrev-ref HEAD"] = { stdout = { "main" } },
        ["git rev-parse"] = { stdout = { MOCK_REV } },
        ["git remote get-url origin"] = { stdout = { "https://github.com/acme/demo.git" } },
        ["git remote"] = { stdout = { "origin" } },
        ["git cat-file"] = {}, -- a successful probe prints nothing
        ["git diff"] = {},
        ["ssh -ttG"] = { stdout = { "hostname github.com" } },
      })
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
      restore_vim_system = mock_vim_system({
        ["git rev-parse --show-toplevel"] = { stdout = { repo_dir } },
        ["git rev-parse --abbrev-ref origin/HEAD"] = { stdout = { "origin/main" } },
        ["git rev-parse --abbrev-ref HEAD"] = { stdout = { "main" } },
        ["git rev-parse"] = { stdout = { MOCK_REV } },
        ["git remote get-url origin"] = { stdout = { "https://github.com/acme/demo.git" } },
        ["git remote"] = { stdout = { "origin" } },
        ["ssh -ttG"] = { stdout = { "hostname github.com" } },
      })
      local url = command_url_of(function()
        vim.cmd([[GitLink file="some dir/a b.lua"]])
      end)
      assert_true(
        url ~= nil and url:find("some%20dir/a%20b.lua", 1, true) ~= nil,
        string.format("url: %s", vim.inspect(url))
      )
    end)

    it("uri-encodes an escaped file path that contains spaces", function()
      restore_vim_system = mock_vim_system({
        ["git rev-parse --show-toplevel"] = { stdout = { repo_dir } },
        ["git rev-parse --abbrev-ref origin/HEAD"] = { stdout = { "origin/main" } },
        ["git rev-parse --abbrev-ref HEAD"] = { stdout = { "main" } },
        ["git rev-parse"] = { stdout = { MOCK_REV } },
        ["git remote get-url origin"] = { stdout = { "https://github.com/acme/demo.git" } },
        ["git remote"] = { stdout = { "origin" } },
        ["ssh -ttG"] = { stdout = { "hostname github.com" } },
      })
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
      restore_vim_system = mock_vim_system({
        ["git rev-parse --show-toplevel"] = { stdout = { cwd } },
        ["git rev-parse --abbrev-ref origin/HEAD"] = { stdout = { "origin/main" } },
        ["git rev-parse --abbrev-ref HEAD"] = { stdout = { "main" } },
        ["git rev-parse"] = { stdout = { MOCK_REV } },
        ["git remote get-url origin"] = { stdout = { "https://github.com/acme/demo.git" } },
        ["git remote"] = { stdout = { "origin" } },
        ["git cat-file"] = {}, -- a successful probe prints nothing
        ["git diff"] = {},
        ["ssh -ttG"] = { stdout = { "hostname github.com" } },
      })
      gitlinker.link()
      gitlinker.link({})
      gitlinker.link({
        action = function(url)
          print(string.format("link-browse-1:%s\n", vim.inspect(url)))
        end,
      })
    end)
    it("blame", function()
      restore_vim_system = mock_vim_system({
        ["git rev-parse --show-toplevel"] = { stdout = { cwd } },
        ["git rev-parse --abbrev-ref origin/HEAD"] = { stdout = { "origin/main" } },
        ["git rev-parse --abbrev-ref HEAD"] = { stdout = { "main" } },
        ["git rev-parse"] = { stdout = { MOCK_REV } },
        ["git remote get-url origin"] = { stdout = { "https://github.com/acme/demo.git" } },
        ["git remote"] = { stdout = { "origin" } },
        ["git cat-file"] = {}, -- a successful probe prints nothing
        ["git diff"] = {},
        ["ssh -ttG"] = { stdout = { "hostname github.com" } },
      })
      gitlinker.link({ router_type = "blame" })
    end)
    it("default_branch", function()
      restore_vim_system = mock_vim_system({
        ["git rev-parse --show-toplevel"] = { stdout = { cwd } },
        ["git rev-parse --abbrev-ref origin/HEAD"] = { stdout = { "origin/main" } },
        ["git rev-parse --abbrev-ref HEAD"] = { stdout = { "main" } },
        ["git rev-parse"] = { stdout = { MOCK_REV } },
        ["git remote get-url origin"] = { stdout = { "https://github.com/acme/demo.git" } },
        ["git remote"] = { stdout = { "origin" } },
        ["git cat-file"] = {}, -- a successful probe prints nothing
        ["git diff"] = {},
        ["ssh -ttG"] = { stdout = { "hostname github.com" } },
      })
      gitlinker.link({ router_type = "default_branch" })
    end)
    it("does not mutate the options table it is handed", function()
      -- A keymap closure hands the same table to every press, so resolving the
      -- line range into it would freeze the range of the first press.
      restore_vim_system = mock_vim_system({
        ["git rev-parse --show-toplevel"] = { stdout = { cwd } },
        ["git rev-parse --abbrev-ref origin/HEAD"] = { stdout = { "origin/main" } },
        ["git rev-parse --abbrev-ref HEAD"] = { stdout = { "main" } },
        ["git rev-parse"] = { stdout = { MOCK_REV } },
        ["git remote get-url origin"] = { stdout = { "https://github.com/acme/demo.git" } },
        ["git remote"] = { stdout = { "origin" } },
        ["git cat-file"] = {}, -- a successful probe prints nothing
        ["git diff"] = {},
        ["ssh -ttG"] = { stdout = { "hostname github.com" } },
      })
      local opts = { router_type = "blame" }
      gitlinker.link(opts)
      assert_eq(opts.router_type, "blame")
      assert_eq(opts.action, nil)
      assert_eq(opts.router, nil)
      assert_eq(opts.lstart, nil)
      assert_eq(opts.lend, nil)
    end)

    --- Link with `opts` and return the urls the action received, the error
    --- messages logged along the way, and every message printed to the user.
    ---
    --- `log.err()`/`log.info()` notify from a scheduled callback, so the loop
    --- has to run once before the messages can be read back.
    ---
    --- @param opts table
    --- @return string[] urls, string[] errors, {msg:string, level:integer}[] messages
    local function link_and_capture(opts)
      local urls, errors, messages = {}, {}, {}
      local notify = vim.notify
      vim.notify = function(msg, level)
        table.insert(messages, { msg = msg, level = level })
        if level == vim.log.levels.ERROR then
          table.insert(errors, msg)
        end
      end
      -- A case that checks what happens when the action raises hands in its
      -- own; only the cases that just want the url get the collector.
      if opts.action == nil then
        opts.action = function(url)
          table.insert(urls, url)
        end
      end
      local ok, err = pcall(gitlinker.link, opts)
      vim.wait(300)
      vim.notify = notify
      assert_true(ok, err)
      return urls, errors, messages
    end

    it("prints the url without escaping its percent signs again", function()
      -- `vim.uri_encode` turns a space into `%20`, and `vim.notify` renders the
      -- string verbatim. Doubling the `%` for a printf-shaped consumer that is
      -- no longer in the picture made the printed link disagree with the one
      -- in the clipboard.
      restore_vim_system = mock_vim_system({
        ["git rev-parse --show-toplevel"] = { stdout = { cwd } },
        ["git rev-parse --abbrev-ref origin/HEAD"] = { stdout = { "origin/main" } },
        ["git rev-parse --abbrev-ref HEAD"] = { stdout = { "main" } },
        ["git rev-parse"] = { stdout = { MOCK_REV } },
        ["git remote get-url origin"] = { stdout = { "https://github.com/acme/demo.git" } },
        ["git remote"] = { stdout = { "origin" } },
        ["git cat-file"] = {}, -- a successful probe prints nothing
        ["git diff"] = {},
        ["ssh -ttG"] = { stdout = { "hostname github.com" } },
      })
      local urls, errors, messages = link_and_capture({
        file = "some dir/a b.lua",
        lstart = 1,
        lend = 1,
      })
      assert_eq(#errors, 0, string.format("errors: %s", vim.inspect(errors)))
      assert_eq(#urls, 1)

      local info = {}
      for _, m in ipairs(messages) do
        if m.level == vim.log.levels.INFO then
          table.insert(info, m.msg)
        end
      end
      assert_eq(#info, 1, string.format("messages: %s", vim.inspect(messages)))
      assert_true(
        info[1]:find("some%20dir/a%20b.lua", 1, true) ~= nil,
        string.format("message: %s", vim.inspect(info[1]))
      )
      assert_true(
        info[1]:find("%%20", 1, true) == nil,
        string.format("message: %s", vim.inspect(info[1]))
      )
    end)

    it("links the whole default branch name when it contains a slash", function()
      -- `git rev-parse --abbrev-ref origin/HEAD` prints the branch as
      -- `origin/release/v5`. Keeping only the last `/`-separated piece built a
      -- link to a branch named `v5`, which the remote does not have.
      restore_vim_system = mock_vim_system({
        ["git rev-parse --show-toplevel"] = { stdout = { cwd } },
        ["git rev-parse --abbrev-ref origin/HEAD"] = { stdout = { "origin/release/v5" } },
        ["git rev-parse --abbrev-ref HEAD"] = { stdout = { "main" } },
        ["git rev-parse"] = { stdout = { MOCK_REV } },
        ["git remote get-url origin"] = { stdout = { "https://github.com/acme/demo.git" } },
        ["git remote"] = { stdout = { "origin" } },
        ["git cat-file"] = {}, -- a successful probe prints nothing
        ["git diff"] = {},
        ["ssh -ttG"] = { stdout = { "hostname github.com" } },
      })
      local urls, errors = link_and_capture({ router_type = "default_branch" })
      assert_eq(#errors, 0, string.format("errors: %s", vim.inspect(errors)))
      assert_eq(#urls, 1)
      assert_true(
        urls[1]:find("/blob/release/v5/", 1, true) ~= nil,
        string.format("url: %s", vim.inspect(urls[1]))
      )
    end)

    it("links a single line when the caller names only one end", function()
      restore_vim_system = mock_vim_system({
        ["git rev-parse --show-toplevel"] = { stdout = { cwd } },
        ["git rev-parse --abbrev-ref origin/HEAD"] = { stdout = { "origin/main" } },
        ["git rev-parse --abbrev-ref HEAD"] = { stdout = { "main" } },
        ["git rev-parse"] = { stdout = { MOCK_REV } },
        ["git remote get-url origin"] = { stdout = { "https://github.com/acme/demo.git" } },
        ["git remote"] = { stdout = { "origin" } },
        ["git cat-file"] = {}, -- a successful probe prints nothing
        ["git diff"] = {},
        ["ssh -ttG"] = { stdout = { "hostname github.com" } },
      })
      -- A half-given range used to reach `luaeval` as `vim.NIL`, which the
      -- default templates compared with a number and raised from inside the
      -- template. The other end is now filled in from the one that was given.
      local urls, errors = link_and_capture({ lend = 6 })
      assert_eq(#errors, 0, string.format("errors: %s", vim.inspect(errors)))
      assert_eq(#urls, 1)
      assert_eq(urls[1]:match("#L[%dL%-]*$"), "#L6")
    end)

    it("links the same single line for the other end", function()
      restore_vim_system = mock_vim_system({
        ["git rev-parse --show-toplevel"] = { stdout = { cwd } },
        ["git rev-parse --abbrev-ref origin/HEAD"] = { stdout = { "origin/main" } },
        ["git rev-parse --abbrev-ref HEAD"] = { stdout = { "main" } },
        ["git rev-parse"] = { stdout = { MOCK_REV } },
        ["git remote get-url origin"] = { stdout = { "https://github.com/acme/demo.git" } },
        ["git remote"] = { stdout = { "origin" } },
        ["git cat-file"] = {}, -- a successful probe prints nothing
        ["git diff"] = {},
        ["ssh -ttG"] = { stdout = { "hostname github.com" } },
      })
      local urls, errors = link_and_capture({ lstart = 6 })
      assert_eq(#errors, 0, string.format("errors: %s", vim.inspect(errors)))
      assert_eq(#urls, 1)
      assert_eq(urls[1]:match("#L[%dL%-]*$"), "#L6")
    end)

    it("sorts a reversed range instead of dropping its end", function()
      restore_vim_system = mock_vim_system({
        ["git rev-parse --show-toplevel"] = { stdout = { cwd } },
        ["git rev-parse --abbrev-ref origin/HEAD"] = { stdout = { "origin/main" } },
        ["git rev-parse --abbrev-ref HEAD"] = { stdout = { "main" } },
        ["git rev-parse"] = { stdout = { MOCK_REV } },
        ["git remote get-url origin"] = { stdout = { "https://github.com/acme/demo.git" } },
        ["git remote"] = { stdout = { "origin" } },
        ["git cat-file"] = {}, -- a successful probe prints nothing
        ["git diff"] = {},
        ["ssh -ttG"] = { stdout = { "hostname github.com" } },
      })
      -- `LEND` used to fall back to `LSTART` here, so the url silently named a
      -- single line instead of the range the caller asked for.
      local urls, errors = link_and_capture({ lstart = 5, lend = 3 })
      assert_eq(#errors, 0, string.format("errors: %s", vim.inspect(errors)))
      assert_eq(#urls, 1)
      assert_eq(urls[1]:match("#L[%dL%-]*$"), "#L3-L5")
    end)

    it("links a single line range given by the caller", function()
      restore_vim_system = mock_vim_system({
        ["git rev-parse --show-toplevel"] = { stdout = { cwd } },
        ["git rev-parse --abbrev-ref origin/HEAD"] = { stdout = { "origin/main" } },
        ["git rev-parse --abbrev-ref HEAD"] = { stdout = { "main" } },
        ["git rev-parse"] = { stdout = { MOCK_REV } },
        ["git remote get-url origin"] = { stdout = { "https://github.com/acme/demo.git" } },
        ["git remote"] = { stdout = { "origin" } },
        ["git cat-file"] = {}, -- a successful probe prints nothing
        ["git diff"] = {},
        ["ssh -ttG"] = { stdout = { "hostname github.com" } },
      })
      local urls, errors = link_and_capture({ lstart = 2, lend = 2 })
      assert_eq(#errors, 0, string.format("errors: %s", vim.inspect(errors)))
      assert_eq(#urls, 1)
      assert_eq(urls[1]:match("#L[%dL%-]*$"), "#L2")
    end)

    it("moves a line range that starts before the first line onto it", function()
      restore_vim_system = mock_vim_system({
        ["git rev-parse --show-toplevel"] = { stdout = { cwd } },
        ["git rev-parse --abbrev-ref origin/HEAD"] = { stdout = { "origin/main" } },
        ["git rev-parse --abbrev-ref HEAD"] = { stdout = { "main" } },
        ["git rev-parse"] = { stdout = { MOCK_REV } },
        ["git remote get-url origin"] = { stdout = { "https://github.com/acme/demo.git" } },
        ["git remote"] = { stdout = { "origin" } },
        ["git cat-file"] = {}, -- a successful probe prints nothing
        ["git diff"] = {},
        ["ssh -ttG"] = { stdout = { "hostname github.com" } },
      })
      -- `#L0` and `#L-3-L-1` name no line of any file, so the remote answers
      -- with a 404 that says nothing about the real problem.
      local urls, errors = link_and_capture({ lstart = 0, lend = 0 })
      assert_eq(#errors, 0, string.format("errors: %s", vim.inspect(errors)))
      assert_eq(#urls, 1)
      assert_eq(urls[1]:match("#L[%dL%-]*$"), "#L1")

      local neg_urls, neg_errors = link_and_capture({ lstart = -3, lend = -1 })
      assert_eq(#neg_errors, 0, string.format("errors: %s", vim.inspect(neg_errors)))
      assert_eq(#neg_urls, 1)
      assert_eq(neg_urls[1]:match("#L[%dL%-]*$"), "#L1")
    end)

    it("moves an end below the first line onto it, keeping the other one", function()
      restore_vim_system = mock_vim_system({
        ["git rev-parse --show-toplevel"] = { stdout = { cwd } },
        ["git rev-parse --abbrev-ref origin/HEAD"] = { stdout = { "origin/main" } },
        ["git rev-parse --abbrev-ref HEAD"] = { stdout = { "main" } },
        ["git rev-parse"] = { stdout = { MOCK_REV } },
        ["git remote get-url origin"] = { stdout = { "https://github.com/acme/demo.git" } },
        ["git remote"] = { stdout = { "origin" } },
        ["git cat-file"] = {}, -- a successful probe prints nothing
        ["git diff"] = {},
        ["ssh -ttG"] = { stdout = { "hostname github.com" } },
      })
      -- Line 0 does not exist, so it becomes the nearest line that does, and the
      -- usable end is still part of the range instead of being thrown away.
      local urls, errors = link_and_capture({ lstart = 9, lend = 0 })
      assert_eq(#errors, 0, string.format("errors: %s", vim.inspect(errors)))
      assert_eq(#urls, 1)
      assert_eq(urls[1]:match("#L[%dL%-]*$"), "#L1-L9")
    end)

    it("rounds a fractional line range down to whole lines", function()
      restore_vim_system = mock_vim_system({
        ["git rev-parse --show-toplevel"] = { stdout = { cwd } },
        ["git rev-parse --abbrev-ref origin/HEAD"] = { stdout = { "origin/main" } },
        ["git rev-parse --abbrev-ref HEAD"] = { stdout = { "main" } },
        ["git rev-parse"] = { stdout = { MOCK_REV } },
        ["git remote get-url origin"] = { stdout = { "https://github.com/acme/demo.git" } },
        ["git remote"] = { stdout = { "origin" } },
        ["git cat-file"] = {}, -- a successful probe prints nothing
        ["git diff"] = {},
        ["ssh -ttG"] = { stdout = { "hostname github.com" } },
      })
      -- `#L1.5-L2.5` is not a link either, and `vim.fn.col({2.5, "$"})` raised
      -- `E805` while computing the highlight, which the coroutine swallowed
      -- before the url was ever made. Getting a url back proves neither
      -- happens anymore.
      local urls, errors = link_and_capture({ lstart = 1.5, lend = 2.5 })
      assert_eq(#errors, 0, string.format("errors: %s", vim.inspect(errors)))
      assert_eq(#urls, 1)
      assert_eq(urls[1]:match("#L[%dL%-]*$"), "#L1-L2")
    end)

    it("falls back to the cursor line for an infinite or NaN line number", function()
      restore_vim_system = mock_vim_system({
        ["git rev-parse --show-toplevel"] = { stdout = { cwd } },
        ["git rev-parse --abbrev-ref origin/HEAD"] = { stdout = { "origin/main" } },
        ["git rev-parse --abbrev-ref HEAD"] = { stdout = { "main" } },
        ["git rev-parse"] = { stdout = { MOCK_REV } },
        ["git remote get-url origin"] = { stdout = { "https://github.com/acme/demo.git" } },
        ["git remote"] = { stdout = { "origin" } },
        ["git cat-file"] = {}, -- a successful probe prints nothing
        ["git diff"] = {},
        ["ssh -ttG"] = { stdout = { "hostname github.com" } },
      })
      -- Neither survives `math.floor()` as something `vim.fn.col()` takes, and
      -- there is no line to move them onto, so they count as not given.
      local inf_urls, inf_errors = link_and_capture({ lstart = math.huge, lend = math.huge })
      assert_eq(#inf_errors, 0, string.format("errors: %s", vim.inspect(inf_errors)))
      assert_eq(#inf_urls, 1)
      assert_eq(inf_urls[1]:match("#L[%dL%-]*$"), "#L1")

      local nan_urls, nan_errors = link_and_capture({ lstart = 0 / 0, lend = 0 / 0 })
      assert_eq(#nan_errors, 0, string.format("errors: %s", vim.inspect(nan_errors)))
      assert_eq(#nan_urls, 1)
      assert_eq(nan_urls[1]:match("#L[%dL%-]*$"), "#L1")
    end)

    it("reports the error when the revision cannot be resolved", function()
      restore_vim_system = mock_vim_system({
        ["git rev-parse --show-toplevel"] = { stdout = { cwd } },
        ["git rev-parse --abbrev-ref origin/HEAD"] = { stdout = { "origin/main" } },
        ["git rev-parse --abbrev-ref HEAD"] = { stdout = { "main" } },
        ["git rev-parse"] = { stdout = { MOCK_REV } },
        ["git remote get-url origin"] = { stdout = { "https://github.com/acme/demo.git" } },
        ["git remote"] = { stdout = { "origin" } },
        ["git cat-file"] = {}, -- a successful probe prints nothing
        ["git diff"] = {},
        ["ssh -ttG"] = { stdout = { "hostname github.com" } },
        -- Every revspec fails, so the revision detection runs out of
        -- candidates and reports its own fatal. No fetch refspec is
        -- configured, which keeps the search on the local history.
        ["git rev-parse"] = { code = 128, stderr = { "fatal: bad revision" } },
        ["git config remote.origin.fetch"] = { code = 1 },
      })
      local urls, errors = link_and_capture({ lstart = 2, lend = 2 })
      assert_eq(#urls, 0)
      assert_eq(#errors, 1)
      assert_true(errors[1]:find("failed to get closest revision", 1, true) ~= nil)
    end)

    it("reports the error when the file is missing from the revision", function()
      restore_vim_system = mock_vim_system({
        ["git rev-parse --show-toplevel"] = { stdout = { cwd } },
        ["git rev-parse --abbrev-ref origin/HEAD"] = { stdout = { "origin/main" } },
        ["git rev-parse --abbrev-ref HEAD"] = { stdout = { "main" } },
        ["git rev-parse"] = { stdout = { MOCK_REV } },
        ["git remote get-url origin"] = { stdout = { "https://github.com/acme/demo.git" } },
        ["git remote"] = { stdout = { "origin" } },
        ["git cat-file"] = {}, -- a successful probe prints nothing
        ["git diff"] = {},
        ["ssh -ttG"] = { stdout = { "hostname github.com" } },
        ["git cat-file"] = { code = 128, stderr = { "fatal: path 'demo.txt' does not exist" } },
      })
      local urls, errors = link_and_capture({ lstart = 2, lend = 2 })
      assert_eq(#urls, 0)
      assert_eq(#errors, 1)
      assert_true(errors[1]:find("does not exist", 1, true) ~= nil)
    end)

    it("reports the error when git cannot be spawned", function()
      -- `vim.system` raises instead of invoking its callback when the binary or
      -- the directory is missing; the fake raises the same way here.
      restore_vim_system = mock_vim_system({
        ["git rev-parse --show-toplevel"] = { stdout = { cwd } },
        ["git rev-parse --abbrev-ref origin/HEAD"] = { stdout = { "origin/main" } },
        ["git rev-parse --abbrev-ref HEAD"] = { stdout = { "main" } },
        ["git rev-parse"] = { stdout = { MOCK_REV } },
        ["git remote get-url origin"] = { stdout = { "https://github.com/acme/demo.git" } },
        ["git remote"] = { stdout = { "origin" } },
        ["git cat-file"] = {}, -- a successful probe prints nothing
        ["git diff"] = {},
        ["ssh -ttG"] = { stdout = { "hostname github.com" } },
        ["git rev-parse --show-toplevel"] = { spawn_error = "ENOENT: no such file or directory" },
      })
      local urls, errors = link_and_capture({ lstart = 2, lend = 2 })
      assert_eq(#urls, 0)
      assert_eq(#errors, 1)
      assert_true(errors[1]:find("ENOENT", 1, true) ~= nil)
    end)

    it("reports the error an action raises", function()
      -- The action runs inside a task nobody waits on, so an error raised here
      -- used to vanish: no message, no `v:errmsg`, nothing to report to a user
      -- whose clipboard function is broken.
      restore_vim_system = mock_vim_system({
        ["git rev-parse --show-toplevel"] = { stdout = { cwd } },
        ["git rev-parse --abbrev-ref origin/HEAD"] = { stdout = { "origin/main" } },
        ["git rev-parse --abbrev-ref HEAD"] = { stdout = { "main" } },
        ["git rev-parse"] = { stdout = { MOCK_REV } },
        ["git remote get-url origin"] = { stdout = { "https://github.com/acme/demo.git" } },
        ["git remote"] = { stdout = { "origin" } },
        ["git cat-file"] = {}, -- a successful probe prints nothing
        ["git diff"] = {},
        ["ssh -ttG"] = { stdout = { "hostname github.com" } },
      })
      local urls, errors = link_and_capture({
        lstart = 2,
        lend = 2,
        action = function()
          error("BOOM-ACTION")
        end,
      })
      assert_eq(#urls, 0)
      assert_eq(#errors, 1)
      assert_true(errors[1]:find("BOOM-ACTION", 1, true) ~= nil)
    end)

    it("reports the error a highlight raises", function()
      -- The highlight is drawn from a scheduled callback, after the link is
      -- done. Its failure cannot fail the link, but it should still be a
      -- message rather than a traceback printed behind the user's back.
      restore_vim_system = mock_vim_system({
        ["git rev-parse --show-toplevel"] = { stdout = { cwd } },
        ["git rev-parse --abbrev-ref origin/HEAD"] = { stdout = { "origin/main" } },
        ["git rev-parse --abbrev-ref HEAD"] = { stdout = { "main" } },
        ["git rev-parse"] = { stdout = { MOCK_REV } },
        ["git remote get-url origin"] = { stdout = { "https://github.com/acme/demo.git" } },
        ["git remote"] = { stdout = { "origin" } },
        ["git cat-file"] = {}, -- a successful probe prints nothing
        ["git diff"] = {},
        ["ssh -ttG"] = { stdout = { "hostname github.com" } },
      })
      local highlight = require("gitlinker.highlight")
      local show = highlight.show
      highlight.show = function()
        error("BOOM-HIGHLIGHT")
      end
      local captured_ok, urls, errors = pcall(link_and_capture, { lstart = 2, lend = 2 })
      highlight.show = show
      assert_true(captured_ok, vim.inspect(urls))
      assert_eq(#urls, 1)
      assert_eq(#errors, 1)
      assert_true(errors[1]:find("BOOM-HIGHLIGHT", 1, true) ~= nil)
    end)

    it("links the buffer the caller started from, not the one open when git answers", function()
      -- `_link` yields to the event loop before it reads the buffer name, so an
      -- `:edit` that lands inside one of those waits used to move the link to
      -- the file the user had just switched to.
      restore_vim_system = mock_vim_system({
        ["git rev-parse --show-toplevel"] = { stdout = { cwd } },
        ["git rev-parse --abbrev-ref origin/HEAD"] = { stdout = { "origin/main" } },
        ["git rev-parse --abbrev-ref HEAD"] = { stdout = { "main" } },
        ["git rev-parse"] = { stdout = { MOCK_REV } },
        ["git remote get-url origin"] = function()
          vim.cmd([[edit README.md]])
          return { stdout = { "https://github.com/acme/demo.git" } }
        end,
        ["git remote"] = { stdout = { "origin" } },
        ["git cat-file"] = {}, -- a successful probe prints nothing
        ["git diff"] = {},
        ["ssh -ttG"] = { stdout = { "hostname github.com" } },
      })
      local urls, errors = link_and_capture({ lstart = 1, lend = 1 })
      assert_eq(#errors, 0, string.format("errors: %s", vim.inspect(errors)))
      assert_eq(#urls, 1)
      assert_true(urls[1]:find("/lua/gitlinker.lua", 1, true) ~= nil, urls[1])
      assert_true(urls[1]:find("README", 1, true) == nil, urls[1])
    end)
  end)
end)
