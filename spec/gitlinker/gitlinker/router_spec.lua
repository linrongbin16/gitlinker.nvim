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
        remote_url = "",
        protocol = "",
        username = nil,
        password = nil,
        host = "github.enterprise.com",
      }

      --- @alias gitlinker.Linker {remote_url:string,protocol:string?,username:string?,password:string?,host:string,port:string?,org:string?,user:string?,repo:string,rev:string,file:string,lstart:integer,lend:integer,file_changed:boolean,default_branch:string?,current_branch:string?}
      -- routers.samba_browse()
    end)
  end)
end)
