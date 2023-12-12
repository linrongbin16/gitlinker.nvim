-- Json encode/decode

local M = {
  encode = (vim.fn.has("nvim-0.9") and vim.json ~= nil) and vim.json.encode
    or require("gitlinker.commons.actboy168_json").encode,
  decode = (vim.fn.has("nvim-0.9") and vim.json ~= nil) and vim.json.decode
    or require("gitlinker.commons.actboy168_json").decode,
}

return M
