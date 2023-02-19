local M = {}

local defaults = {
  remote = "origin", -- force the use of a specific remote
  add_current_line_on_normal_mode = true, -- if true adds the line nr in the url for normal mode
  action_callback = require("gitlinker.actions").open_in_browser, -- callback for what to do with the url
  print_url = true, -- print the url after action
  mappings = "<leader>gl", -- copy git link to clipboard
}

local opts = {}

function M.setup(options)
  opts = vim.tbl_deep_extend("force", defaults, options or {})
end

function M.get()
  return opts
end

return M
