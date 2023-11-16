local logger = require("gitlinker.logger")
local linker = require("gitlinker.linker")
local highlight = require("gitlinker.highlight")
local deprecation = require("gitlinker.deprecation")
local utils = require("gitlinker.utils")

--- @alias gitlinker.Options table<any, any>
--- @type gitlinker.Options
local Defaults = {
  -- print permanent url in command line
  message = true,

  -- highlight the linked region
  highlight_duration = 500,

  -- highlight group, by default link to `Search`
  highlight_group = {
    NvimGitLinkerHighlightTextObject = { link = "Search" },
  },

  -- user command
  command = {
    -- by default 'GitLink' will copy link to clipboard with browse router
    -- to open link in browser, use bang: 'GitLink!'
    -- to use blame router, use: 'GitLink router=blame'.
    -- to use browse router, use: 'GitLink router=browse' (which is the default router).
    name = "GitLink",
    desc = "Generate git permanent link",

    -- to fully customize the generated url, please override below routers.
    router = {
      browse = require("gitlinker.routers").browse,
      blame = require("gitlinker.routers").blame,
    },
  },

  -- key mappings
  mapping = {
    ["<leader>gl"] = {
      action = require("gitlinker.actions").clipboard,
      desc = "Copy git link to clipboard",
    },
    ["<leader>gL"] = {
      action = require("gitlinker.actions").system,
      desc = "Open git link in browser",
    },
  },

  -- router bindings
  router_binding = {
    browse = {
      ["^github%.com"] = require("gitlinker.routers").github_browse,
      ["^gitlab%.com"] = require("gitlinker.routers").gitlab_browse,
      ["^bitbucket%.org"] = require("gitlinker.routers").bitbucket_browse,
    },
    blame = {
      ["^github%.com"] = require("gitlinker.routers").github_blame,
      ["^gitlab%.com"] = require("gitlinker.routers").gitlab_blame,
      ["^bitbucket%.org"] = require("gitlinker.routers").bitbucket_blame,
    },
  },

  -- enable debug
  debug = false,

  -- write logs to console(command line)
  console_log = true,

  -- write logs to file
  file_log = false,
}

--- @type gitlinker.Options
local Configs = {}

--- @param opts gitlinker.Options
local function deprecated_notification(opts)
  if type(opts) == "table" and opts.pattern_rules ~= nil then
    deprecation.notify(
      "'pattern_rules' is deprecated! please migrate to latest configs."
    )
  end
  if type(opts) == "table" and opts.override_rules ~= nil then
    deprecation.notify(
      "'override_rules' is deprecated! please migrate to latest configs."
    )
  end
  if type(opts) == "table" and opts.custom_rules ~= nil then
    deprecation.notify(
      "'custom_rules' is deprecated! please migrate to latest configs."
    )
  end
end

--- @param args string
local function parse_command_input(args) end

--- @param opts gitlinker.Options?
local function setup(opts)
  local browse_bindings = vim.deepcopy(Defaults.router_binding.browse)
  local blame_bindings = vim.deepcopy(Defaults.router_binding.blame)
  local user_browse_bindings = (
    type(opts) == "table"
    and type(opts.router_binding) == "table"
    and type(opts.router_binding.browse) == "table"
  )
      and vim.deepcopy(opts.router_binding.browse)
    or {}
  local user_blame_bindings = (
    type(opts) == "table"
    and type(opts.router_binding) == "table"
    and type(opts.router_binding.blame) == "table"
  )
      and vim.deepcopy(opts.router_binding.blame)
    or {}
  browse_bindings =
    vim.tbl_extend("force", browse_bindings, user_browse_bindings)
  blame_bindings = vim.tbl_extend("force", blame_bindings, user_blame_bindings)
  Configs = vim.tbl_deep_extend("force", vim.deepcopy(Defaults), opts or {})
  Configs.router_binding = {
    browse = browse_bindings,
    blame = blame_bindings,
  }

  -- logger
  logger.setup({
    level = Configs.debug and "DEBUG" or "INFO",
    console_log = Configs.console_log,
    file_log = Configs.file_log,
  })

  -- router binding
  require("gitlinker.routers").setup(Configs.router_binding or {})

  -- command
  vim.api.nvim_create_user_command(Configs.command.name, function(command_opts)
    logger.debug("command opts:%s", vim.insepct(command_opts))
    local args = command_opts.args
  end, {
    args = "*",
    range = true,
    bang = true,
    desc = Configs.command.desc,
  })

  -- key mappings
  local key_mappings = nil
  if type(opts) == "table" and opts["mapping"] ~= nil then
    if type(opts["mapping"]) == "table" then
      key_mappings = opts["mapping"]
    end
  else
    key_mappings = Defaults.mapping
  end

  if type(key_mappings) == "table" then
    for k, v in pairs(key_mappings) do
      local opt = {
        noremap = true,
        silent = true,
      }
      if v.desc then
        opt.desc = v.desc
      end
      vim.keymap.set({ "n", "v" }, k, function()
        require("gitlinker").link({ action = v.action, router = v.router })
      end, opt)
    end
  end

  -- Configure highlight group
  if Configs.highlight_duration > 0 then
    local hl_group = "NvimGitLinkerHighlightTextObject"
    if not highlight.hl_group_exists(hl_group) then
      vim.api.nvim_set_hl(0, hl_group, Configs.highlight_group[hl_group])
    end
  end

  -- logger.debug("|setup| Configs:%s", vim.inspect(Configs))

  deprecated_notification(Configs)
end

--- @param opts gitlinker.Options?
--- @return string?
local function link(opts)
  opts = vim.tbl_deep_extend("force", vim.deepcopy(Configs), opts or {})
  -- logger.debug("[link] merged opts: %s", vim.inspect(opts))
  deprecated_notification(opts)

  local range = (type(opts.lstart) == "number" and type(opts.lend) == "number")
      and { lstart = opts.lstart, lend = opts.lend }
    or nil
  local lk = linker.make_linker(range)
  if not lk then
    return nil
  end

  local router = opts.router or require("gitlinker.routers").browse
  if not router then
    return nil
  end

  local ok, url = pcall(router, lk)
  logger.ensure(
    ok and type(url) == "string" and string.len(url) > 0,
    "fatal: failed to generate permanent url from remote url (%s): %s",
    vim.inspect(lk.remote_url),
    vim.inspect(url)
  )

  if opts.action then
    opts.action(url)
  end

  if opts.highlight_duration > 0 then
    highlight.show({ lstart = lk.lstart, lend = lk.lend })
    vim.defer_fn(highlight.clear, opts.highlight_duration)
  end

  if opts.message then
    local msg = lk.file_changed
        and string.format("%s (lines can be wrong due to file change)", url)
      or url
    logger.info(msg)
  end

  return url
end

local M = {
  setup = setup,
  link = link,
}

return M
