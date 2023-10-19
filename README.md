<!-- markdownlint-disable MD013 MD034 -->

# gitlinker.nvim

<p align="center">
<a href="https://github.com/neovim/neovim/releases/v0.7.0"><img alt="Neovim-v0.7" src="https://img.shields.io/badge/Neovim-v0.7-blueviolet.svg?logo=Neovim&logoColor=green" /></a>
<a href="https://github.com/linrongbin16/gitlinker.nvim/search?l=lua"><img alt="Top Language" src="https://img.shields.io/github/languages/top/linrongbin16/gitlinker.nvim?label=Lua&logo=lua&logoColor=darkblue" /></a>
<a href="https://github.com/linrongbin16/gitlinker.nvim/blob/master/LICENSE"><img alt="License" src="https://img.shields.io/github/license/linrongbin16/gitlinker.nvim?logo=GNU&label=License" /></a>
<a href="https://github.com/linrongbin16/gitlinker.nvim/actions/workflows/ci.yml"><img alt="ci.yml" src="https://img.shields.io/github/actions/workflow/status/linrongbin16/gitlinker.nvim/ci.yml?logo=GitHub&label=Luacheck" /></a>
<a href="https://app.codecov.io/github/linrongbin16/gitlinker.nvim"><img alt="codecov" src="https://img.shields.io/codecov/c/github/linrongbin16/gitlinker.nvim?logo=codecov&logoColor=magenta&label=Codecov" /></a>
</p>

> A fork of [ruifm's gitlinker](https://github.com/ruifm/gitlinker.nvim), refactored
> with pattern based rule engine, Windows support and other enhancements.

A lua plugin for [Neovim](https://github.com/neovim/neovim) to generate sharable
file permalinks (with line ranges) for git host websites. Inspired by
[tpope/vim-fugitive](https://github.com/tpope/vim-fugitive)'s `:GBrowse`.

An example of git permalink:
<https://github.com/neovim/neovim/blob/2e156a3b7d7e25e56b03683cc6228c531f4c91ef/src/nvim/main.c#L137-L156>

Personally, I use this all the time to easily share code locations with my
co-workers.

- [Break Changes & Updates](#break-changes--updates)
  - [Lua pattern based rules](#lua-pattern-based-rules)
- [Installation](#installation)
  - [packer.nvim](#packernvim)
  - [vim-plug](#vim-plug)
  - [lazy.nvim](#lazynvim)
- [Usage](#usage)
  - [Action](#action)
  - [API](#api)
  - [Key Mappings](#key-mappings)
  - [Customization](#customization)
- [Configuration](#configuration)

## Break Changes & Updates

1. Bug fix:
   - Customize default key mappings.
   - Windows support.
2. Improvements:
   - Url mapping engine migrate to lua pattern based rules from hard coding.
   - Use stderr from git command as error message.
   - Use `uv.spawn` for performant git command stdout/stderr.
   - Drop off `plenary` library.
   - Re-designed API.
   - Logger.

### Lua pattern based rules

[Lua pattern](https://www.lua.org/pil/20.2.html) is introduced to map git remote
url to host url. The lua pattern has many limitations compared with the
[standard regex expression](https://en.wikipedia.org/wiki/Regular_expression),
but it's still the best solution in this scenario.

For now supported platforms are:

- github.com
- gitlab.com

PRs are welcomed for other git host websites!

## Installation

Requirement:

- git.
- neovim &ge; v0.7.

### [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
    'linrongbin16/gitlinker.nvim',
    config = function()
        require('gitlinker').setup()
    end,
}
```

### [vim-plug](https://github.com/junegunn/vim-plug)

```vim
call plug#begin()

Plug 'linrongbin16/gitlinker.nvim'

call plug#end()

lua<<EOF
require('gitlinker').setup()
EOF
```

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
    'linrongbin16/gitlinker.nvim',
    config = function()
        require('gitlinker').setup()
    end,
},
```

# Usage

## Action

- `require('gitlinker.actions').clipboard`: copy git link to clipboard.
- `require('gitlinker.actions').system`: open git link in browser.

## API

- `require('gitlinker').link(option)`: the main API that generate the git permalink, the `option` is a lua table that has below fields:

  ```lua
  {
      action = ..., -- gitlinker actions: clipboard/system
      lstart = ..., -- selected line start, please see in [Customization](#customization).
      lend = ..., -- selected line end, please see in [Customization](#customization).
  }
  ```

There're no pre-defined vim command, you need to use:

- `require('gitlinker').link({ action = require('gitlinker.actions').clipboard })` to copy git link.
- `require('gitlinker').link({ action = require('gitlinker.actions').system })` to open git link.

## Key Mappings

The above two operations are already defined with two default key mappings:

- `<leader>gl` (normal/visual mode): copy git link to clipboard.
- `<leader>gL` (normal/visual mode): open git link in browser.

## Customization

To disable the default key mappings, set `mapping = false` in `setup()` function
(see [Configuration](#configuration)).

To create your own key mappings, please specify the `mapping` option
in `setup()` function.

To create your own vim command, please use:

For vim:

```vim
command! -range GitLink lua require('gitlinker').link({ action = require('gitlinker.actions').system, lstart = vim.api.nvim_buf_get_mark(0, '<')[1], lend = vim.api.nvim_buf_get_mark(0, '>')[1] })
```

For lua:

```lua
vim.api.nvim_create_user_command("GitLink", function()
    require("gitlinker").link({
        action = require("gitlinker.actions").system,
        lstart = vim.api.nvim_buf_get_mark(0, '<')[1],
        lend = vim.api.nvim_buf_get_mark(0, '>')[1]
    })
end, {
    range = true,
})
```

> Support command range is a little bit tricky, please read https://github.com/linrongbin16/gitlinker.nvim/discussions/38 and https://github.com/linrongbin16/gitlinker.nvim/issues/47.

## Configuration

````lua
require('gitlinker').setup({
  -- print message in command line
  message = true,

  -- key mapping
  mapping = {
    ["<leader>gl"] = {
      -- copy git link to clipboard
      action = require("gitlinker.actions").clipboard,
      desc = "Copy git link to clipboard",
    },
    ["<leader>gL"] = {
      -- open git link in browser
      action = require("gitlinker.actions").system,
      desc = "Open git link in browser",
    },
  },

  -- regex pattern based rules
  pattern_rules = {
    {
      ["^git@github%.([_%.%-%w]+):([%.%-%w]+)/([_%.%-%w]+)%.git$"] = "https://github.%1/%2/%3/blob/",
      ["^https?://github%.([_%.%-%w]+)/([%.%-%w]+)/([_%.%-%w]+)%.git$"] = "https://github.%1/%2/%3/blob/",
      ["^git@gitlab%.([_%.%-%w]+):([%.%-%w]+)/([_%.%-%w]+)%.git$"] = "https://gitlab.%1/%2/%3/blob/",
      ["^https?://gitlab%.([_%.%-%w]+)/([%.%-%w]+)/([_%.%-%w]+)%.git$"] = "https://gitlab.%1/%2/%3/blob/",
    },
    {
      ["^git@github%.([_%.%-%w]+):([%.%-%w]+)/([_%.%-%w]+)$"] = "https://github.%1/%2/%3/blob/",
      ["^https?://github%.([_%.%-%w]+)/([%.%-%w]+)/([_%.%-%w]+)$"] = "https://github.%1/%2/%3/blob/",
      ["^git@gitlab%.([_%.%-%w]+):([%.%-%w]+)/([_%.%-%w]+)$"] = "https://gitlab.%1/%2/%3/blob/",
      ["^https?://gitlab%.([_%.%-%w]+)/([%.%-%w]+)/([_%.%-%w]+)$"] = "https://gitlab.%1/%2/%3/blob/",
    },
  },

  -- function based rules: function(remote_url) => host_url.
  -- this function will override the `pattern_rules`.
  -- here's an example of custom_rules:
  --
  -- ```
  -- custom_rules = function(remote_url)
  --   local pattern_rules = {
  --     {
  --       ["^git@github%.([_%.%-%w]+):([%.%-%w]+)/([%.%-%w]+)%.git$"] = "https://github.%1/%2/%3/blob/",
  --       ["^https://github%.([_%.%-%w]+)/([%.%-%w]+)/([%.%-%w]+)%.git$"] = "https://github.%1/%2/%3/blob/",
  --     },
  --     -- http(s)://github.(com|*)/linrongbin16/gitlinker.nvim(.git)? -> https://github.com/linrongbin16/gitlinker.nvim(.git)?
  --     {
  --       ["^git@github%.([_%.%-%w]+):([%.%-%w]+)/([%.%-%w]+)$"] = "https://github.%1/%2/%3/blob/",
  --       ["^https://github%.([_%.%-%w]+)/([%.%-%w]+)/([%.%-%w]+)$"] = "https://github.%1/%2/%3/blob/",
  --     },
  --   }
  --   for _, group in ipairs(pattern_rules) do
  --     for pattern, replace in pairs(group) do
  --       if string.match(remote_url, pattern) then
  --         local result = string.gsub(remote_url, pattern, replace)
  --         return result
  --       end
  --     end
  --   end
  --   return nil
  -- end,
  -- ```
  --
  --- @overload fun(remote_url:string):string|nil
  custom_rules = nil,


  -- enable debug
  debug = false,

  -- write logs to console(command line)
  console_log = true,

  -- write logs to file
  file_log = false,
})
````

## Development

To develop the project and make PR, please setup with:

- [lua_ls](https://github.com/LuaLS/lua-language-server).
- [stylua](https://github.com/JohnnyMorganz/StyLua).
- [luarocks](https://luarocks.org/).
- [luacheck](https://github.com/mpeterv/luacheck).

To run unit tests, please install below dependencies:

- [vusted](https://github.com/notomo/vusted).

Then test with `vusted ./test`.

## Contribute

Please also open [issue](https://github.com/linrongbin16/lin.nvim/issues)/[PR](https://github.com/linrongbin16/lin.nvim/pulls) for anything about gitlinker.nvim.

Like gitlinker.nvim? Consider

[![Github Sponsor](https://img.shields.io/badge/-Sponsor%20Me%20on%20Github-magenta?logo=github&logoColor=white)](https://github.com/sponsors/linrongbin16)
[![Wechat Pay](https://img.shields.io/badge/-Tip%20Me%20on%20WeChat-brightgreen?logo=wechat&logoColor=white)](https://linrongbin16.github.io/sponsor)
[![Alipay](https://img.shields.io/badge/-Tip%20Me%20on%20Alipay-blue?logo=alipay&logoColor=white)](https://linrongbin16.github.io/sponsor)
