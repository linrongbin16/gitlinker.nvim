vim.o.number = true
vim.o.autoread = true
vim.o.autowrite = true
vim.o.swapfile = false
vim.o.confirm = true

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
    vim.fn.system({
        "git",
        "clone",
        "--filter=blob:none",
        "https://github.com/folke/lazy.nvim.git",
        "--branch=stable", -- latest stable release
        lazypath,
    })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
    {
        "linrongbin16/gitlinker.nvim",
        dev = true,
        config = function()
            require("gitlinker").setup()
        end,
    },
}, { dev = { path = "~/github/linrongbin16" }, defaults = { lazy = false } })

require("lazy").sync({ wait = true, show = false })
