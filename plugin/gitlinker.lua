if vim.fn.exists("g:loaded_gitlinker") == 0 then
  require("gitlinker").setup()
end
