-- Luv wrapper

local M = (vim.fn.has("nvim-0.10") > 0 and vim.uv ~= nil) and vim.uv or vim.loop

return M
