if vim.g.loaded_gitlinker then
  return
end

vim.api.nvim_create_user_command("GitLink", function(command_opts)
  require("gitlinker")._command(command_opts)
end, {
  nargs = "*",
  range = true,
  bang = true,
  desc = "Generate git permanent link",
  complete = function(arg_lead)
    return require("gitlinker")._complete(arg_lead)
  end,
})
