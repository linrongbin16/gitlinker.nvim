<!-- markdownlint-disable MD013 MD034 -->

# gitlinker.nvim

<p align="center">
<a href="https://github.com/neovim/neovim/releases/v0.7.0"><img alt="Neovim" src="https://img.shields.io/badge/Neovim-v0.7-57A143?logo=neovim&logoColor=57A143" /></a>
<a href="https://github.com/linrongbin16/gitlinker.nvim/search?l=lua"><img alt="Language" src="https://img.shields.io/github/languages/top/linrongbin16/gitlinker.nvim?label=Lua&logo=lua&logoColor=fff&labelColor=2C2D72" /></a>
<a href="https://github.com/linrongbin16/gitlinker.nvim/actions/workflows/ci.yml"><img alt="ci.yml" src="https://img.shields.io/github/actions/workflow/status/linrongbin16/gitlinker.nvim/ci.yml?label=GitHub%20CI&labelColor=181717&logo=github&logoColor=fff" /></a>
<a href="https://app.codecov.io/github/linrongbin16/gitlinker.nvim"><img alt="codecov" src="https://img.shields.io/codecov/c/github/linrongbin16/gitlinker.nvim?logo=codecov&logoColor=F01F7A&label=Codecov" /></a>
</p>

> Maintained fork of [ruifm's gitlinker](https://github.com/ruifm/gitlinker.nvim), refactored with bug fixes, ssh host alias, `/blame` url support and other improvements.

A lua plugin for [Neovim](https://github.com/neovim/neovim) to generate sharable file permalinks (with line ranges) for git host websites. Inspired by [tpope/vim-fugitive](https://github.com/tpope/vim-fugitive)'s `:GBrowse`.

Here's an example of git permalink: https://github.com/neovim/neovim/blob/2e156a3b7d7e25e56b03683cc6228c531f4c91ef/src/nvim/main.c#L137-L156.

![gitlinker](https://github.com/linrongbin16/gitlinker.nvim/assets/6496887/0d83fd82-4726-4dae-a70d-2c07236981b6)

For now supported platforms are:

- [github.com](https://github.com/)
- [gitlab.com](https://gitlab.com/)
- [bitbucket.org](https://bitbucket.org/)
- [codeberg.org](https://codeberg.org/)
- [git.samba.org](https://git.samba.org/)

PRs are welcomed for other git host websites!

## Table of Contents

- [Break Changes & Updates](#break-changes--updates)
- [Installation](#installation)
  - [packer.nvim](#packernvim)
  - [vim-plug](#vim-plug)
  - [lazy.nvim](#lazynvim)
- [Usage](#usage)
- [Configuration](#configuration)
  - [Highlighting](#highlighting)
  - [Self-host Git Hosts](#self-host-git-hosts)
  - [Fully Customize Urls](#fully-customize-urls)
  - [GitWeb](#gitweb)
  - [More Router Types](#more-router-types)
- [Highlight Group](#highlight-group)
- [Development](#development)
- [Contribute](#contribute)

## Break Changes & Updates

1. Break Changes:
   - Provide `GitLink` command instead of default key mappings.
2. New Features:
   - Windows (+wsl) support.
   - Respect ssh host alias.
   - Add `?plain=1` for markdown files.
   - Support `/blame` (by default is `/blob`).
3. Improvements:
   - Use stderr from git command as error message.
   - Performant child process IO via `uv.spawn`.
   - Drop off `plenary` dependency.

## Installation

Requirement:

- neovim &ge; v0.7.
- [git](https://git-scm.com/).
- [ssh](https://www.openssh.com/) (optional for resolve ssh host alias).

### [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
return require('packer').startup(function(use)
  use {
    'linrongbin16/gitlinker.nvim',
    config = function()
      require('gitlinker').setup()
    end,
  }
end)
```

### [vim-plug](https://github.com/junegunn/vim-plug)

```vim
call plug#begin()

Plug 'linrongbin16/gitlinker.nvim'

call plug#end()

lua require('gitlinker').setup()
```

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
require("lazy").setup({
  {
    'linrongbin16/gitlinker.nvim',
    config = function()
      require('gitlinker').setup()
    end,
  },
})
```

## Usage

You could use below command:

- `GitLink`: copy the `/blob` url to clipboard.
- `GitLink!`: open the `/blob` url in browser.
- `GitLink blame`: copy the `/blame` url to clipboard.
- `GitLink! blame`: open the `/blame` url in browser.

There're two **routers** provided:

- `browse`: generate the `/blob` urls (default router in `GitLink`), also work for other git host websites, e.g. generate `/src` for bitbucket.org.
- `blame`: generate the `/blame` urls, also work for other git host websites, e.g. generate `/annotate` for bitbucket.org.

<details>
<summary><i>Click here to see recommended key mappings</i></summary>
<br/>

```lua
-- browse
vim.keymap.set(
  {"n", 'v'},
  "<leader>gl",
  "<cmd>GitLink<cr>",
  { silent = true, noremap = true, desc = "Copy git permlink to clipboard" }
)
vim.keymap.set(
  {"n", 'v'},
  "<leader>gL",
  "<cmd>GitLink!<cr>",
  { silent = true, noremap = true, desc = "Open git permlink in browser" }
)
-- blame
vim.keymap.set(
  {"n", 'v'},
  "<leader>gb",
  "<cmd>GitLink blame<cr>",
  { silent = true, noremap = true, desc = "Copy git blame link to clipboard" }
)
vim.keymap.set(
  {"n", 'v'},
  "<leader>gB",
  "<cmd>GitLink! blame<cr>",
  { silent = true, noremap = true, desc = "Open git blame link in browser" }
)
```

</details>

## Configuration

```lua
require('gitlinker').setup({
  -- print message in command line
  message = true,

  -- highlights the linked line(s) by the time in ms
  -- disable highlight by setting a value equal or less than 0
  highlight_duration = 500,

  -- user command
  command = {
    -- to copy link to clipboard, use: 'GitLink'
    -- to open link in browser, use bang: 'GitLink!'
    -- to use blame router, use: 'GitLink blame' and 'GitLink! blame'
    name = "GitLink",
    desc = "Generate git permanent link",
  },

  -- router bindings
  router = {
    browse = {
      -- example: https://github.com/linrongbin16/gitlinker.nvim/blob/9679445c7a24783d27063cd65f525f02def5f128/lua/gitlinker.lua#L3-L4
      ["^github%.com"] = "https://github.com/"
        .. "{_A.USER}/"
        .. "{_A.REPO}/blob/"
        .. "{_A.REV}/"
        .. "{_A.FILE}"
        .. "{(string.len(_A.FILE) >= 3 and _A.FILE:sub(#_A.FILE-2) == '.md') and '?plain=1' or ''}" -- '?plain=1'
        .. "#L{_A.LSTART}"
        .. "{(_A.LEND > _A.LSTART and ('-L' .. _A.LEND) or '')}",
      -- example: https://gitlab.com/linrongbin16/gitlinker.nvim/blob/9679445c7a24783d27063cd65f525f02def5f128/lua/gitlinker.lua#L3-L4
      ["^gitlab%.com"] = "https://gitlab.com/"
        .. "{_A.USER}/"
        .. "{_A.REPO}/blob/"
        .. "{_A.REV}/"
        .. "{_A.FILE}"
        .. "#L{_A.LSTART}"
        .. "{(_A.LEND > _A.LSTART and ('-L' .. _A.LEND) or '')}",
      -- example: https://bitbucket.org/linrongbin16/gitlinker.nvim/src/9679445c7a24783d27063cd65f525f02def5f128/lua/gitlinker.lua#lines-3:4
      ["^bitbucket%.org"] = "https://bitbucket.org/"
        .. "{_A.USER}/"
        .. "{_A.REPO}/src/"
        .. "{_A.REV}/"
        .. "{_A.FILE}"
        .. "#lines-{_A.LSTART}"
        .. "{(_A.LEND > _A.LSTART and (':' .. _A.LEND) or '')}",
      -- example: https://codeberg.org/linrongbin16/gitlinker.nvim/src/commit/a570f22ff833447ee0c58268b3bae4f7197a8ad8/LICENSE#L5-L6
      ["^codeberg%.org"] = "https://codeberg.org/"
        .. "{_A.USER}/"
        .. "{_A.REPO}/src/commit/"
        .. "{_A.REV}/"
        .. "{_A.FILE}"
        .. "{(string.len(_A.FILE) >= 3 and _A.FILE:sub(#_A.FILE-2) == '.md') and '?display=source' or ''}" -- '?display=source'
        .. "#L{_A.LSTART}"
        .. "{(_A.LEND > _A.LSTART and ('-L' .. _A.LEND) or '')}",
      -- example:
      -- main repo: https://git.samba.org/?p=samba.git;a=blob;f=wscript;hb=83e8971c0f1c1db8c3574f83107190ac1ac23db0#l6
      -- dev repo: https://git.samba.org/?p=bbaumbach/samba.git;a=blob;f=wscript;hb=8de348e9d025d336a7985a9025fe08b7096c0394#l7
      ["^git%.samba%.org"] = "https://git.samba.org/?"
        .. "p={string.len(_A.REPO) == 0 and _A.USER or (_A.USER .. '/' .. _A.REPO .. '.git')};a=blob;" -- 'p=samba.git' or 'p=bbaumbach/samba.git'
        .. "f={_A.FILE};"
        .. "hb={_A.REV}"
        .. "#l{_A.LSTART}",
    },
    blame = {
      -- example: https://github.com/linrongbin16/gitlinker.nvim/blame/9679445c7a24783d27063cd65f525f02def5f128/lua/gitlinker.lua#L3-L4
      ["^github%.com"] = "https://github.com/"
        .. "{_A.USER}/"
        .. "{_A.REPO}/blame/"
        .. "{_A.REV}/"
        .. "{_A.FILE}"
        .. "{(string.len(_A.FILE) >= 3 and _A.FILE:sub(#_A.FILE-2) == '.md') and '?plain=1' or ''}"
        .. "#L{_A.LSTART}"
        .. "{(_A.LEND > _A.LSTART and ('-L' .. _A.LEND) or '')}",
      -- example: https://gitlab.com/linrongbin16/gitlinker.nvim/blame/9679445c7a24783d27063cd65f525f02def5f128/lua/gitlinker.lua#L3-L4
      ["^gitlab%.com"] = "https://gitlab.com/"
        .. "{_A.USER}/"
        .. "{_A.REPO}/blame/"
        .. "{_A.REV}/"
        .. "{_A.FILE}"
        .. "#L{_A.LSTART}"
        .. "{(_A.LEND > _A.LSTART and ('-L' .. _A.LEND) or '')}",
      -- example: https://bitbucket.org/linrongbin16/gitlinker.nvim/annotate/9679445c7a24783d27063cd65f525f02def5f128/lua/gitlinker.lua#lines-3:4
      ["^bitbucket%.org"] = "https://bitbucket.org/"
        .. "{_A.USER}/"
        .. "{_A.REPO}/annotate/"
        .. "{_A.REV}/"
        .. "{_A.FILE}"
        .. "#lines-{_A.LSTART}"
        .. "{(_A.LEND > _A.LSTART and (':' .. _A.LEND) or '')}",
      -- example: https://codeberg.org/linrongbin16/gitlinker.nvim/blame/commit/a570f22ff833447ee0c58268b3bae4f7197a8ad8/LICENSE#L5-L6
      ["^codeberg%.org"] = "https://codeberg.org/"
        .. "{_A.USER}/"
        .. "{_A.REPO}/blame/commit/"
        .. "{_A.REV}/"
        .. "{_A.FILE}"
        .. "#L{_A.LSTART}"
        .. "{(_A.LEND > _A.LSTART and ('-L' .. _A.LEND) or '')}",
    },
  },

  -- enable debug
  debug = false,

  -- write logs to console(command line)
  console_log = true,

  -- write logs to file
  file_log = false,
})
```

### Highlighting

To create your own highlighting, please use below config before setup this plugin:

```lua
-- lua
vim.api.nvim_set_hl( 0, "NvimGitLinkerHighlightTextObject", { link = "Constant" })
```

```vim
" vimscript
hi link NvimGitLinkerHighlightTextObject Constant
```

> Also see [Highlight Group](#highlight-group).

### Self-host Git Hosts

For self-host git host websites, please add more bindings in `router` option.

Below example shows how to apply the github style routers to a self-host github websites, e.g. `github.your.host`:

```lua
require('gitlinker').setup({
  router = {
    browse = {
      -- add your host here
      ["^github%.your%.host"] = require('gitlinker.routers').github_browse,
    },
    blame = {
      -- add your host here
      ["^github%.your%.host"] = require('gitlinker.routers').github_blame,
    },
  },
})
```

You can directly use below builtin APIs:

- `github_browse`/`github_blame`: for [github.com](https://github.com/).
- `gitlab_browse`/`gitlab_blame`: for [gitlab.com](https://gitlab.com/).
- `bitbucket_browse`/`bitbucket_blame`: for [bitbucket.org](https://bitbucket.org/).
- `codeberg_browse`/`codeberg_blame`: for [codeberg.org](https://codeberg.org/).
- `samba_browse`: for [git.samba.org](https://git.samba.org/) (blame not support).

### Fully Customize Urls

To fully customize url generation, please refer to the implementation of [routers.lua](https://github.com/linrongbin16/gitlinker.nvim/blob/master/lua/gitlinker/routers.lua), a router is simply construct the url string from below components:

- `protocol`: `git@`, `ssh://git@`, `https`, etc.
- `host`: `github.com`, `gitlab.com`, `bitbucket.org`, etc.
- `user`: `linrongbin16` (for this plugin), `neovim` (for [neovim](https://github.com/neovim/neovim)), etc.
- `repo`: `gitlinker.nvim.git`, `neovim.git`, etc.
- `rev`: git commit, e.g. `dbf3922382576391fbe50b36c55066c1768b08b6`.
- `file`: file name, e.g. `lua/gitlinker/routers.lua`.
- `lstart`/`lend`: start/end line numbers, e.g. `#L37-L156`.

For example you can customize the line numbers in form `?&line=1&lines-count=2` like this:

```lua
--- @param s string
--- @param t string
local function string_endswith(s, t)
  return string.len(s) >= string.len(t) and string.sub(s, #s - #t + 1) == t
end

--- @param lk gitlinker.Linker
local function your_router(lk)
  local builder = "https://"
  -- host: 'github.com', 'gitlab.com', 'bitbucket.org'
  builder = builder .. lk.host .. "/"
  -- user: 'linrongbin16', 'neovim'
  builder = builder .. lk.user .. "/"
  -- repo: 'gitlinker.nvim.git', 'neovim'
  builder = builder
    .. (string_endswith(lk.repo, ".git") and lk.repo:sub(1, #lk.repo - 4) or lk.repo)
    .. "/"
  -- rev: git commit, e.g. 'e605210941057849491cca4d7f44c0e09f363a69'
  builder = lk.rev .. "/"
  -- file: 'lua/gitlinker/logger.lua'
  builder = builder
    .. lk.file
    .. (string_endswith(lk.file, ".md") and "?plain=1" or "")
  -- line range: start line number, end line number
  builder = builder .. string.format("&lines=%d", lk.lstart)
  if lk.lend > lk.lstart then
    builder = builder
      .. string.format("&lines-count=%d", lk.lend - lk.lstart + 1)
  end
  return builder
end

require("gitlinker").setup({
  router = {
    browse = {
      ["^github%.your%.host"] = your_router,
    },
  },
})
```

Quite a lot of engineering effort, isn't it? You can also use the url template, which should be easier to define the url schema:

> The url template is also the default implementation of builtin routers (see `router` option in [Configuration](#configuration)), but the error message could be confusing if there's any syntax issue.

```lua
require("gitlinker").setup({
  router = {
    browse = {
      ["^github%.your%.host"] = "https://github.your.host/"
        .. "{_A.USER}/"
        .. "{_A.REPO}/blob/"
        .. "{_A.REV}/"
        .. "{_A.FILE}"
        .. "?&lines={_A.LSTART}"
        .. "{_A.LEND > _A.LSTART and ('&lines-count=' .. _A.LEND - _A.LSTART + 1) or ''}",
    },
  },
})
```

The template string use curly braces `{}` to contains lua scripts, and evaluate via [luaeval()](https://neovim.io/doc/user/lua.html#lua-eval).

The available variables are the same with the `lk` parameter passing to hook functions, but in upper case, and with the `_A.` prefix:

- `_A.PROTOCOL`: `git@`, `ssh://git@`, `https`, etc.
- `_A.HOST`: `github.com`, `gitlab.com`, `bitbucket.org`, etc.
- `_A.USER`: `linrongbin16` (for this plugin), `neovim` (for [neovim](https://github.com/neovim/neovim)), etc.
- `_A.REPO`: `gitlinker.nvim`, `neovim`, etc.
  - **Note:** for easier writing, the `.git` suffix has been removed.
- `_A.REV`: git commit, e.g. `dbf3922382576391fbe50b36c55066c1768b08b6`.
- `_A.FILE`: file name, e.g. `lua/gitlinker/routers.lua`.
- `_A.LSTART`/`_A.LEND`: start/end line numbers, e.g. `#L37-L156`.

### GitWeb

For [GitWeb](https://git-scm.com/book/en/v2/Git-on-the-Server-GitWeb), there're two types of urls: the main repository and the user's dev repository. For example on [git.samba.org](https://git.samba.org/):

- Main repo: https://git.samba.org/?p=samba.git;a=blob;f=wscript;hb=83e8971c0f1c1db8c3574f83107190ac1ac23db0#l7.
- User's dev repo: https://git.samba.org/?p=bbaumbach/samba.git;a=blob;f=wscript;hb=8de348e9d025d336a7985a9025fe08b7096c0394#l7.

Take a closer look at them:

```bash
# main repo
https://git.samba.org/?p=samba.git;a=blob;f=wscript;hb=83e8971c0f1c1db8c3574f83107190ac1ac23db0#l7
|       |                |                  |          |                                         |
protocol host            repo               file       rev                                       line number

# user dev repo
https://git.samba.org/?p=bbaumbach/samba.git;a=blob;f=wscript;hb=8de348e9d025d336a7985a9025fe08b7096c0394#l7
|       |                |         |                  |          |                                         |
protocol host            user      repo               file       rev                                       line number
```

> Also see difference between `h` and `hb` in gitweb url:
>
> 1. https://stackoverflow.com/q/14444593/4438921.
> 2. https://stackoverflow.com/a/14444767/4438921.

The difference is: the main repo doesn't have the `user` component, it's just `https://git.samba.org/?p=samba.git`. To support such case, `user` and `repo` components have a little bit different:

- `lk.user` (`_A.USER`): the value is `samba.git`.
- `lk.repo` (`_A.REPO`): the value is `` (empty string).

> Actually it should be more likely the `lk.user` is empty string, and `lk.repo` is `samba.git`, but I'm just parsing it in this way.

### More Router Types

You can even create your own router type (e.g. use the same engine with `browse`/`blame`), for example create the `master_branch` router type:

```lua
require("gitlinker").setup({
  router = {
    master_branch = {
      ["^github%.com"] = "https://github.com/"
        .. "{_A.USER}/"
        .. "{_A.REPO}/blob/master/" -- always 'master' branch
        .. "{_A.FILE}"
        .. "?&lines={_A.LSTART}"
        .. "{_A.LEND > _A.LSTART and ('&lines-count=' .. _A.LEND - _A.LSTART + 1) or ''}",
    },
  },
})
```

## Highlight Group

| Highlight Group                  | Default Group | Description                          |
| -------------------------------- | ------------- | ------------------------------------ |
| NvimGitLinkerHighlightTextObject | Search        | highlight line ranges when copy/open |

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

Please also open [issue](https://github.com/linrongbin16/gitlinker.nvim/issues)/[PR](https://github.com/linrongbin16/gitlinker.nvim/pulls) for anything about gitlinker.nvim.

Like gitlinker.nvim? Consider

[![Github Sponsor](https://img.shields.io/badge/-Sponsor%20Me%20on%20Github-magenta?logo=github&logoColor=white)](https://github.com/sponsors/linrongbin16)
[![Wechat Pay](https://img.shields.io/badge/-Tip%20Me%20on%20WeChat-brightgreen?logo=wechat&logoColor=white)](https://linrongbin16.github.io/sponsor)
[![Alipay](https://img.shields.io/badge/-Tip%20Me%20on%20Alipay-blue?logo=alipay&logoColor=white)](https://linrongbin16.github.io/sponsor)
