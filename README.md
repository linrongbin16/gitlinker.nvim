<!-- markdownlint-disable MD013 MD034 MD033 -->

# gitlinker.nvim

<p align="center">
<a href="https://github.com/neovim/neovim/releases/v0.7.0"><img alt="Neovim" src="https://img.shields.io/badge/Neovim-v0.7+-57A143?logo=neovim&logoColor=57A143" /></a>
<a href="https://github.com/linrongbin16/commons.nvim"><img alt="commons.nvim" src="https://custom-icon-badges.demolab.com/badge/Powered_by-commons.nvim-teal?logo=heart&logoColor=fff&labelColor=deeppink" /></a>
<a href="https://luarocks.org/modules/linrongbin16/gitlinker.nvim"><img alt="luarocks" src="https://custom-icon-badges.demolab.com/luarocks/v/linrongbin16/gitlinker.nvim?label=LuaRocks&labelColor=063B70&logo=tag&logoColor=fff&color=blue" /></a>
<a href="https://github.com/linrongbin16/gitlinker.nvim/actions/workflows/ci.yml"><img alt="ci.yml" src="https://img.shields.io/github/actions/workflow/status/linrongbin16/gitlinker.nvim/ci.yml?label=GitHub%20CI&labelColor=181717&logo=github&logoColor=fff" /></a>
<a href="https://app.codecov.io/github/linrongbin16/gitlinker.nvim"><img alt="codecov" src="https://img.shields.io/codecov/c/github/linrongbin16/gitlinker.nvim?logo=codecov&logoColor=F01F7A&label=Codecov" /></a>
</p>

> Maintained fork of [ruifm's gitlinker](https://github.com/ruifm/gitlinker.nvim), refactored with bug fixes, ssh host alias, `/blame` url support and other improvements.

A lua plugin for [Neovim](https://github.com/neovim/neovim) to generate sharable file permalinks (with line ranges) for git host websites. Inspired by [tpope/vim-fugitive](https://github.com/tpope/vim-fugitive)'s `:GBrowse`.

Here's an example of git permalink: https://github.com/neovim/neovim/blob/2e156a3b7d7e25e56b03683cc6228c531f4c91ef/src/nvim/main.c#L137-L156.

https://github.com/linrongbin16/gitlinker.nvim/assets/6496887/d3e425a5-cf08-487f-badc-d393ca9dda2f

For now supported platforms are:

- [github.com](https://github.com/)
- [gitlab.com](https://gitlab.com/)
- [bitbucket.org](https://bitbucket.org/)
- [codeberg.org](https://codeberg.org/)
- [git.samba.org](https://git.samba.org/)

PRs are welcomed for other git host websites!

## Table of Contents

- [Break Changes & Updates](#break-changes--updates)
- [Requirements](#requirements)
- [Installation](#installation)
- [Usage](#usage)
- [Configuration](#configuration)
  - [Highlighting](#highlighting)
  - [Self-host Git Hosts](#self-host-git-hosts)
  - [Fully Customize Urls](#fully-customize-urls)
  - [Create Your Own Router](#create-your-own-router)
- [Highlight Group](#highlight-group)
- [Development](#development)
- [Contribute](#contribute)

## Break Changes & Updates

1. Break Changes:
   - Provide `GitLink` command instead of default key mappings.
2. New Features:
   - Windows (+wsl2) support.
   - Respect ssh host alias.
   - Add `?plain=1` for markdown files.
   - Support `/blame` (by default is `/blob`).
   - Full [git protocols](https://git-scm.com/book/en/v2/Git-on-the-Server-The-Protocols) support.
3. Improvements:
   - Use stderr from git command as error message.
   - Async child process IO via coroutine and `uv.spawn`.
   - Drop off 'plenary' dependency.

## Requirements

- Neovim &ge; v0.7.
- [git](https://git-scm.com/).
- [ssh](https://www.openssh.com/) (optional for resolve ssh host alias).
- [wslview](https://github.com/wslutilities/wslu) (optional for open browser from Windows wsl2).

## Installation

<details>
<summary><b>With <a href="https://github.com/folke/lazy.nvim">lazy.nvim</a></b></summary>

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

</details>

<details>
<summary><b>With <a href="https://github.com/lewis6991/pckr.nvim">pckr.nvim</a></b></summary>

```lua
return require('pckr').add(
  {
    'linrongbin16/gitlinker.nvim',
    config = function()
      require('gitlinker').setup()
    end,
  };
)
```

</details>

## Usage

You could use below command:

- `GitLink`: copy the `/blob` url to clipboard.
- `GitLink!`: open the `/blob` url in browser.
- `GitLink blame`: copy the `/blame` url to clipboard.
- `GitLink! blame`: open the `/blame` url in browser.

There're two **routers** provided:

- `browse`: generate the `/blob` url (default).
- `blame`: generate the `/blame` url.

> [!NOTE]
>
> They also work for other git host websites, for example for bitbucket.org.
>
> - `browse`: generate the `/src` url (default).
> - `blame`: generate the `/annotate` url.

By default `GitLink` will use the first detected remote (`origin`), but if you need to specify other remotes, please use `remote=xxx` arguments. For example:

- `GitLink remote=upstream`: copy `upstream` url to clipboard.
- `GitLink! remote=upstream`: open `upstream` url in browser.

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
        .. "{_A.ORG}/"
        .. "{_A.REPO}/blob/"
        .. "{_A.REV}/"
        .. "{_A.FILE}?plain=1" -- '?plain=1'
        .. "#L{_A.LSTART}"
        .. "{(_A.LEND > _A.LSTART and ('-L' .. _A.LEND) or '')}",
      -- example: https://gitlab.com/linrongbin16/gitlinker.nvim/blob/9679445c7a24783d27063cd65f525f02def5f128/lua/gitlinker.lua#L3-L4
      ["^gitlab%.com"] = "https://gitlab.com/"
        .. "{_A.ORG}/"
        .. "{_A.REPO}/blob/"
        .. "{_A.REV}/"
        .. "{_A.FILE}"
        .. "#L{_A.LSTART}"
        .. "{(_A.LEND > _A.LSTART and ('-L' .. _A.LEND) or '')}",
      -- example: https://bitbucket.org/linrongbin16/gitlinker.nvim/src/9679445c7a24783d27063cd65f525f02def5f128/lua/gitlinker.lua#L3-L4
      ["^bitbucket%.org"] = "https://bitbucket.org/"
        .. "{_A.ORG}/"
        .. "{_A.REPO}/src/"
        .. "{_A.REV}/"
        .. "{_A.FILE}"
        .. "#lines-{_A.LSTART}"
        .. "{(_A.LEND > _A.LSTART and (':' .. _A.LEND) or '')}",
      -- example: https://codeberg.org/linrongbin16/gitlinker.nvim/src/commit/a570f22ff833447ee0c58268b3bae4f7197a8ad8/LICENSE#L5-L6
      ["^codeberg%.org"] = "https://codeberg.org/"
        .. "{_A.ORG}/"
        .. "{_A.REPO}/src/commit/"
        .. "{_A.REV}/"
        .. "{_A.FILE}?display=source" -- '?display=source'
        .. "#L{_A.LSTART}"
        .. "{(_A.LEND > _A.LSTART and ('-L' .. _A.LEND) or '')}",
      -- example:
      -- main repo: https://git.samba.org/?p=samba.git;a=blob;f=wscript;hb=83e8971c0f1c1db8c3574f83107190ac1ac23db0#l6
      -- dev repo: https://git.samba.org/?p=bbaumbach/samba.git;a=blob;f=wscript;hb=8de348e9d025d336a7985a9025fe08b7096c0394#l7
      ["^git%.samba%.org"] = "https://git.samba.org/?p="
        .. "{string.len(_A.ORG) > 0 and (_A.ORG .. '/') or ''}" -- 'p=samba.git;' or 'p=bbaumbach/samba.git;'
        .. "{_A.REPO .. '.git'};a=blob;"
        .. "f={_A.FILE};"
        .. "hb={_A.REV}"
        .. "#l{_A.LSTART}",
    },
    blame = {
      -- example: https://github.com/linrongbin16/gitlinker.nvim/blame/9679445c7a24783d27063cd65f525f02def5f128/lua/gitlinker.lua#L3-L4
      ["^github%.com"] = "https://github.com/"
        .. "{_A.ORG}/"
        .. "{_A.REPO}/blame/"
        .. "{_A.REV}/"
        .. "{_A.FILE}?plain=1" -- '?plain=1'
        .. "#L{_A.LSTART}"
        .. "{(_A.LEND > _A.LSTART and ('-L' .. _A.LEND) or '')}",
      -- example: https://gitlab.com/linrongbin16/gitlinker.nvim/blame/9679445c7a24783d27063cd65f525f02def5f128/lua/gitlinker.lua#L3-L4
      ["^gitlab%.com"] = "https://gitlab.com/"
        .. "{_A.ORG}/"
        .. "{_A.REPO}/blame/"
        .. "{_A.REV}/"
        .. "{_A.FILE}"
        .. "#L{_A.LSTART}"
        .. "{(_A.LEND > _A.LSTART and ('-L' .. _A.LEND) or '')}",
      -- example: https://bitbucket.org/linrongbin16/gitlinker.nvim/annotate/9679445c7a24783d27063cd65f525f02def5f128/lua/gitlinker.lua#lines-3:4
      ["^bitbucket%.org"] = "https://bitbucket.org/"
        .. "{_A.ORG}/"
        .. "{_A.REPO}/annotate/"
        .. "{_A.REV}/"
        .. "{_A.FILE}"
        .. "#lines-{_A.LSTART}"
        .. "{(_A.LEND > _A.LSTART and (':' .. _A.LEND) or '')}",
      -- example: https://codeberg.org/linrongbin16/gitlinker.nvim/blame/commit/a570f22ff833447ee0c58268b3bae4f7197a8ad8/LICENSE#L5-L6
      ["^codeberg%.org"] = "https://codeberg.org/"
        .. "{_A.ORG}/"
        .. "{_A.REPO}/blame/commit/"
        .. "{_A.REV}/"
        .. "{_A.FILE}?display=source" -- '?display=source'
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
vim.api.nvim_set_hl(
  0,
  "NvimGitLinkerHighlightTextObject",
  { link = "Constant" }
)
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

- `github_browse`/`github_blame`: for github.com.
- `gitlab_browse`/`gitlab_blame`: for gitlab.com.
- `bitbucket_browse`/`bitbucket_blame`: for bitbucket.org.
- `codeberg_browse`/`codeberg_blame`: for codeberg.org.
- `samba_browse`: for git.samba.org (blame not support).

### Fully Customize Urls

> [!NOTE]
>
> Please refer to [Git Protocols](https://git-scm.com/book/en/v2/Git-on-the-Server-The-Protocols) and [giturlparser](https://github.com/linrongbin16/giturlparser.lua?tab=readme-ov-file#features) for better understanding git url.

To fully customize url generation, please refer to the implementation of [routers.lua](https://github.com/linrongbin16/gitlinker.nvim/blob/master/lua/gitlinker/routers.lua), a router is simply construct the url string from below components:

- `protocol`: Component before `://` delimiter. For example:
  - The `https` in `https://github.com`.
  - The `ssh` in `ssh://github.com`.
- `username`: Optional component between `protocol` and `host` separated by `@` (or `password` separated by `:`). For example:
  - The `git` in `ssh://git@github.com/linrongbin16/gitlinker.nvim.git`.
  - The `myname` in `myname@github.com:linrongbin16/gitlinker.nvim.git` (**Note:** the `ssh://` in ssh protocol can be omitted).
- `password`: Optional component between `username` and `host` separated by `@`. For example:
  - The `mypass` in `ssh://myname:mypass@github.com/linrongbin16/gitlinker.nvim.git`.
  - The `1234` in `git:1234@github.com:linrongbin16/gitlinker.nvim.git`.
- `host`: Component between `protocol` (and optional `username`, `password`) and `path`. For example:
  - The `github.com` in `https://github.com/linrongbin16/gitlinker.nvim` (**Note:** for http/https, `host` ends with `/`).
  - The `127.0.0.1` in `git@127.0.0.1:linrongbin16/gitlinker.nvim` (**Note:** for omitted ssh, `host` ends with `:`, and cannot have the following `port` component).
- `port`: Optional component between `host` and `path` (**Note:** ssh protocol cannot have `port` component). For example:
  - The `22` in `https://github.com:22/linrongbin16/gitlinker.nvim`.
  - The `123456` in `https://127.0.0.1:123456/linrongbin16/gitlinker.nvim`.
- `path`: All the left parts after `host` (and optional `port`). For example:
  - `/linrongbin16/gitlinker.nvim.git` in `https://github.com/linrongbin16/gitlinker.nvim.git`.
  - `path/to/repo.git` in `git@github.com:path/to/repo.git`.
- `rev`: Git commit. For example:
  - The `a009dacda96756a8c418ff5fa689999b148639f6` in `https://github.com/linrongbin16/gitlinker.nvim/blob/a009dacda96756a8c418ff5fa689999b148639f6/lua/gitlinker/git.lua?plain=1#L3`.
- `file`: Relative file path. For example:
  - `lua/gitlinker/routers.lua` in `https://github.com/linrongbin16/gitlinker.nvim/blob/master/lua/gitlinker/routers.lua`.
- `lstart`/`lend`: Start/end line numbers. For example:
  - `3`/`13` in `https://github.com/linrongbin16/gitlinker.nvim/blob/master/lua/gitlinker/routers.lua#L3-L13`.

There're also 2 sugar components derived from `path`:

- `repo`: The last part after the last slash (`/`) in `path`, with around slashes been removed. For example:
  - `gitlinker.nvim.git` in `https://github.com/linrongbin16/gitlinker.nvim`.
  - `neovim.git` in `https://github.com/neovim/neovim.git`.
- `org`: (Optional) all the other parts before `repo` in `path`, with around slashes been removed. For example:
  - `linrongbin16` in `https://github.com/linrongbin16/gitlinker.nvim.git`.
  - `path/to/the` in `https://github.com/path/to/the/repo.git`.

> [!NOTE]
>
> The `org` component can be empty when the `path` only contains 1 slash (`/`), for example:
>
> - `ssh://git@host.xyz/repo.git`.

There're also 2 branch components:

- `default_branch`: Default branch retrieved from `git rev-parse --abbrev-ref origin/HEAD`. For example:
  - `master` in `https://github.com/ruifm/gitlinker.nvim/blob/master/lua/gitlinker/routers.lua#L37-L156`.
  - `main` in `https://github.com/linrongbin16/commons.nvim/blob/main/lua/commons/uv.lua`.
- `current_branch`: Current branch retrieved from `git rev-parse --abbrev-ref HEAD`. For example:
  - `feat-router-types`

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
  -- host
  builder = builder .. lk.host .. "/"
  -- org
  builder = builder .. lk.org .. "/"
  -- repo
  builder = builder
    .. (string_endswith(lk.repo, ".git") and lk.repo:sub(1, #lk.repo - 4) or lk.repo)
    .. "/"
  -- rev
  builder = lk.rev .. "/"
  -- file
  builder = builder
    .. lk.file
    .. (string_endswith(lk.file, ".md") and "?plain=1" or "")
  -- line range
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
        .. "{_A.ORG}/"
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

- `_A.PROTOCOL`
- `_A.USERNAME`
- `_A.PASSWORD`
- `_A.HOST`
- `_A.PORT`
- `_A.PATH`
- `_A.REV`
- `_A.DEFAULT_BRANCH`
- `_A.CURRENT_BRANCH`
- `_A.FILE`
- `_A.LSTART`/`_A.LEND`

The 2 sugar components derived from `path` are:

- `_A.ORG`
- `_A.REPO` - **Note:** for easier writing, the `.git` suffix is been removed.

The 2 branch components are:

- `_A.DEFAULT_BRANCH`
- `_A.CURRENT_BRANCH`

### Create Your Own Router

You can even create your own router (e.g. use the same engine with `browse`/`blame`), for example create the `default_branch`/`current_branch` router type:

```lua
require("gitlinker").setup({
  router = {
    default_branch = {
      ["^github%.com"] = "https://github.com/"
        .. "{_A.ORG}/"
        .. "{_A.REPO}/blob/"
        .. "{_A.DEFAULT_BRANCH}/" -- always 'master'/'main' branch
        .. "{_A.FILE}?plain=1" -- '?plain=1'
        .. "#L{_A.LSTART}"
        .. "{(_A.LEND > _A.LSTART and ('-L' .. _A.LEND) or '')}",
    },
    current_branch = {
      ["^github%.com"] = "https://github.com/"
        .. "{_A.ORG}/"
        .. "{_A.REPO}/blob/"
        .. "{_A.CURRENT_BRANCH}/" -- always current branch
        .. "{_A.FILE}?plain=1" -- '?plain=1'
        .. "#L{_A.LSTART}"
        .. "{(_A.LEND > _A.LSTART and ('-L' .. _A.LEND) or '')}",
    },
  },
})
```

Then use it just like `browse`:

```vim
GitLink default_branch
GitLink! default_branch
GitLink current_branch
GitLink! current_branch
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

Please open [issue](https://github.com/linrongbin16/gitlinker.nvim/issues)/[PR](https://github.com/linrongbin16/gitlinker.nvim/pulls) for anything about gitlinker.nvim.

Like gitlinker.nvim? Consider

[![Github Sponsor](https://img.shields.io/badge/-Sponsor%20Me%20on%20Github-magenta?logo=github&logoColor=white)](https://github.com/sponsors/linrongbin16)
[![Wechat Pay](https://img.shields.io/badge/-Tip%20Me%20on%20WeChat-brightgreen?logo=wechat&logoColor=white)](https://linrongbin16.github.io/sponsor)
[![Alipay](https://img.shields.io/badge/-Tip%20Me%20on%20Alipay-blue?logo=alipay&logoColor=white)](https://linrongbin16.github.io/sponsor)
