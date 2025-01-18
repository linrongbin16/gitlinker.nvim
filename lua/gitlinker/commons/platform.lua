local M = {}

local uv = vim.uv or vim.loop
local os_name = uv.os_uname().sysname
local os_name_valid = type(os_name) == "string" and string.len(os_name) > 0

M.OS_NAME = os_name
M.IS_WINDOWS = os_name_valid and os_name:match("Windows") ~= nil
M.IS_MAC = os_name_valid and os_name:match("Darwin") ~= nil
M.IS_BSD = vim.fn.has("bsd") > 0
M.IS_LINUX = os_name_valid and os_name:match("Linux") ~= nil

return M
