vim.o.number = true
vim.o.autoread = true
vim.o.autowrite = true
vim.o.swapfile = false
vim.o.confirm = true
vim.o.termguicolors = true

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
      require("gitlinker").setup({ debug = true, file_log = true })
    end,
    keys = {
      {
        "<leader>gl",
        function()
          require("gitlinker").link({ action = require("gitlinker.actions").clipboard })
        end,
        mode = { "n", "x" },
        desc = "GitLink",
      },
      {
        "<leader>gL",
        function()
          require("gitlinker").link({ action = require("gitlinker.actions").system })
        end,
        mode = { "n", "x" },
        desc = "GitLink!",
      },
      {
        "<leader>gb",
        function()
          require("gitlinker").link({
            action = require("gitlinker.actions").clipboard,
            router_type = "blame",
          })
        end,
        mode = { "n", "x" },
        desc = "GitLink blame",
      },
      {
        "<leader>gB",
        function()
          require("gitlinker").link({
            action = require("gitlinker.actions").system,
            router_type = "blame",
          })
        end,
        mode = { "n", "x" },
        desc = "GitLink! blame",
      },
      {
        "<leader>gd",
        function()
          require("gitlinker").link({
            action = require("gitlinker.actions").clipboard,
            router_type = "default_branch",
          })
        end,
        mode = { "n", "x" },
        desc = "GitLink default_branch",
      },
      {
        "<leader>gD",
        function()
          require("gitlinker").link({
            action = require("gitlinker.actions").system,
            router_type = "default_branch",
          })
        end,
        mode = { "n", "x" },
        desc = "GitLink! default_branch",
      },
    },
  },
}, {
  dev = { path = "~/github/linrongbin16" },
})

vim.cmd([[ colorscheme darkblue ]])
