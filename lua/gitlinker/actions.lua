--- @alias gitlinker.Action fun(url:string):any

-- copy url to clipboard
--- @param url string
local function clipboard(url)
  vim.api.nvim_command("let @+ = '" .. url .. "'")
end

-- open url in browser
-- see: https://github.com/axieax/urlview.nvim/blob/b183133fd25caa6dd98b415e0f62e51e061cd522/lua/urlview/actions.lua#L38
--- @param url string
local function system(url)
  if vim.fn.has("mac") > 0 then
    vim.fn.jobstart({ "open", url })
  elseif vim.fn.has("win32") > 0 or vim.fn.has("win64") > 0 then
    vim.fn.jobstart({ "cmd", "/C", "start", url })
  elseif vim.fn.executable("wslview") > 0 then
    vim.fn.jobstart({ "wslview", url })
  else
    vim.fn.jobstart({ "xdg-open", url })
  end
end

local M = {
  clipboard = clipboard,
  system = system,
}

return M
