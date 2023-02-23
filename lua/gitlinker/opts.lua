local M = {}

local defaults = {
  remote = "origin", -- force the use of a specific remote
  action_callback = require("gitlinker.actions").open_in_browser, -- callback for what to do with the url
  print_url = true, -- print the url after action
  mappings = "<leader>gl", -- key mappings
  rule = function(remote)
    -- for lua regex pattern test: https://gitspartv.github.io/lua-patterns/
    print("remote:" .. vim.inspect(remote))

    local pattern_rules = {
      -- git@github.(com|*):linrongbin16/gitlinker.nvim(.git)? -> https://github.com/linrongbin16/gitlinker.nvim(.git)?
      ["^git@github%.([_%.%-%w]+):([%.%-%w]+)/([%.%-%w]+)$"] = "https://github.%1/%2/%3",
      -- http(s)://github.(com|*)/linrongbin16/gitlinker.nvim(.git)? -> https://github.com/linrongbin16/gitlinker.nvim(.git)?
      ["^https://github%.([_%.%-%w]+)/([%.%-%w]+)/([%.%-%w]+)$"] = "https://github.%1/%2/%3",
    }

    for pattern, replace in pairs(pattern_rules) do
      if string.match(remote, pattern) then
        local result = string.gsub(remote, pattern, replace)
        print("result:" .. vim.inspect(result))
        return result
      end
    end
    print("result: nil")
    return nil
  end,
  debug = false,
  console_log = true,
  file_log = false,
  file_log_name = "gitlinker.log",
}

local opts

function M.setup(user_opts)
  opts = vim.tbl_deep_extend("force", defaults, user_opts or {})
end

function M.get()
  return opts
end

return M
