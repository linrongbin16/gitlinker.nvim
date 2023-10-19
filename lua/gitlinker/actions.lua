local util = require("gitlinker.util")

--- @alias GitLinkerAction fun(url:string):nil

-- copy url to clipboard
--
--- @param url string
local function clipboard(url)
    vim.api.nvim_command("let @+ = '" .. url .. "'")
end

-- open url in browser
-- see: https://github.com/axieax/urlview.nvim/blob/b183133fd25caa6dd98b415e0f62e51e061cd522/lua/urlview/actions.lua#L38
--
--- @param url string
local function system(url)
    local job
    if util.is_macos() then
        job = vim.fn.jobstart({ "open", url })
    elseif util.is_windows() then
        job = vim.fn.jobstart({ "cmd", "/C", "start", url })
    else
        job = vim.fn.jobstart({ "xdg-open", url })
    end
    vim.fn.jobwait({ job })
end

local M = {
    clipboard = clipboard,
    system = system,
}

return M
