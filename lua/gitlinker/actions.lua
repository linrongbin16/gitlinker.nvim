--- @alias gitlinker.Action fun(url:string):any

-- copy url to clipboard
--- @param url string
local function clipboard(url)
  vim.fn.setreg("+", url)
end

-- open url in browser
--- @param url string
local function system(url)
  vim.ui.open(url)
end

local M = {
  clipboard = clipboard,
  system = system,
}

return M
