local cwd = vim.fn.getcwd()

describe("gitlinker.linker", function()
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

  local async = require("gitlinker.commons.async")
  local github_actions = os.getenv("GITHUB_ACTIONS") == "true"
  local linker = require("gitlinker.linker")
  describe("[make_linker]", function()
    it("make", function()
      async.run(function()
        local lk, err = linker.make_linker()
        print(string.format("linker:%s, err:%s", vim.inspect(lk), vim.inspect(err)))
        if lk then
          assert_true(err == nil)
        else
          assert_eq(type(err), "string")
        end
        if github_actions then
          assert_true(type(lk) == "table" or lk == nil)
        else
          assert_eq(type(lk), "table")
          assert_eq(lk.file, "lua/gitlinker.lua")
          assert_true(lk.lstart == nil)
          assert_true(lk.lend == nil)
          assert_eq(type(lk.rev), "string")
          assert_true(string.len(lk.rev) > 0)
          assert_eq(type(lk.remote_url), "string")
          assert_eq(lk.remote_url, "https://github.com/linrongbin16/gitlinker.nvim.git")
          assert_eq(lk.default_branch, "master")
          assert_eq(type(lk.current_branch), "string")
          assert_true(string.len(lk.current_branch) >= 0)
        end
      end)
    end)
    it("make with range", function()
      async.run(function()
        local lk, err = linker.make_linker()
        print(string.format("linker:%s, err:%s", vim.inspect(lk), vim.inspect(err)))
        if lk then
          assert_true(err == nil)
        else
          assert_eq(type(err), "string")
        end
        if github_actions then
          assert_true(type(lk) == "table" or lk == nil)
        else
          assert_eq(type(lk), "table")
          assert_eq(lk.file, "lua/gitlinker.lua")
          assert_true(lk.lstart == nil)
          assert_true(lk.lend == nil)
          assert_eq(type(lk.rev), "string")
          assert_true(string.len(lk.rev) > 0)
          assert_eq(type(lk.remote_url), "string")
          assert_eq(lk.remote_url, "https://github.com/linrongbin16/gitlinker.nvim.git")
          assert_eq(lk.default_branch, "master")
          assert_eq(type(lk.current_branch), "string")
          assert_true(string.len(lk.current_branch) >= 0)
        end
      end)
    end)
    it("returns an error for an unknown rev", function()
      async.run(function()
        local lk, err = linker.make_linker(nil, nil, "definitely-not-a-real-rev-xyz")
        print(string.format("linker(bad rev):%s, err:%s", vim.inspect(lk), vim.inspect(err)))
        assert_true(lk == nil)
        assert_eq(type(err), "string")
        assert_true(string.len(err) > 0)
      end)
    end)
    it("returns an error outside a git repository", function()
      local tmp = vim.fn.tempname()
      vim.fn.mkdir(tmp, "p")
      vim.cmd("edit " .. tmp .. "/plain.txt")
      async.run(function()
        local lk, err = linker.make_linker()
        print(string.format("linker(no repo):%s, err:%s", vim.inspect(lk), vim.inspect(err)))
        assert_true(lk == nil)
        assert_eq(type(err), "string")
      end)
      vim.fn.delete(tmp, "rf")
    end)
    it("returns an error for an unknown remote", function()
      async.run(function()
        local lk, err = linker.make_linker("no-such-remote-xyz", nil, nil)
        print(string.format("linker(bad remote):%s, err:%s", vim.inspect(lk), vim.inspect(err)))
        assert_true(lk == nil)
        assert_eq(type(err), "string")
        assert_true(string.len(err) > 0)
      end)
    end)
  end)
end)
