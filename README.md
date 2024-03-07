<!-- markdownlint-disable MD013 MD034 MD033 -->

# gitlinker.nvim

<p>
<a href="https://github.com/neovim/neovim/releases/v0.7.0"><img alt="Neovim" src="https://img.shields.io/badge/require-0.7%2B-blue" /></a>
<a href="https://github.com/linrongbin16/commons.nvim"><img alt="commons.nvim" src="https://img.shields.io/badge/power_by-commons.nvim-pink" /></a>
<a href="https://luarocks.org/modules/linrongbin16/gitlinker.nvim"><img alt="luarocks" src="https://img.shields.io/luarocks/v/linrongbin16/gitlinker.nvim" /></a>
<a href="https://github.com/linrongbin16/gitlinker.nvim/actions/workflows/ci.yml"><img alt="ci.yml" src="https://img.shields.io/github/actions/workflow/status/linrongbin16/gitlinker.nvim/ci.yml?label=ci" /></a>
<a href="https://app.codecov.io/github/linrongbin16/gitlinker.nvim"><img alt="codecov" src="https://img.shields.io/codecov/c/github/linrongbin16/gitlinker.nvim/main?label=codecov" /></a>
</p>

> Maintained fork of [ruifm's gitlinker](https://github.com/ruifm/gitlinker.nvim), refactored with bug fixes, ssh host alias, blame support and other improvements.

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
  - [Command](#command)
  - [API](#api)
  - [Recommended Key Mappings](#recommended-key-mappings)
- [Configuration](#configuration)
  - [Customize Urls](#customize-urls)
    - [String Template](#string-template)
    - [Lua Function](#lua-function)
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
   - Support blame url.
   - Full [git protocols](https://git-scm.com/book/en/v2/Git-on-the-Server-The-Protocols) support.
3. Improvements:
   - Use stderr from git command as error message.
   - Async child process IO via coroutine and `uv.spawn`.
   - Drop off `plenary` dependency.

## Requirements

- Neovim &ge; 0.7.
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

### Command

You can use the user command `GitLink` to generate git permlink:

- `GitLink(!)`: copy the `/blob` url to clipboard (use `!` to open in browser).
- `GitLink(!) blame`: copy the `/blame` url to clipboard (use `!` to open in browser).
- `GitLink(!) default_branch`: copy the `/main` or `/master` url to clipboard (use `!` to open in browser).

There're several **router types**:

- `browse`: generate the `/blob` url (default).
- `blame`: generate the `/blame` url.
- `default_branch`: generate the `/main` or `/master` url.

> [!NOTE]
>
> A router type is a general collection of router implementations binding on different git hosts, thus it can work for any git hosts, for example for [bitbucket.org](https://bitbucket.org/):
>
> - `browse` generate the `/src` url (default): https://bitbucket.org/gitlinkernvim/gitlinker.nvim/src/dbf3922382576391fbe50b36c55066c1768b08b6/.gitignore#lines-9:14.
> - `blame` generate the `/annotate` url: https://bitbucket.org/gitlinkernvim/gitlinker.nvim/annotate/dbf3922382576391fbe50b36c55066c1768b08b6/.gitignore#lines-9:14.
> - `default_branch` generate the `/main` or `/master` url based on actual project: https://bitbucket.org/gitlinkernvim/gitlinker.nvim/src/master/.gitignore#lines-9:14.

There're several arguments:

- `remote`: by default `GitLink` will use the first detected remote (usually it's `origin`), but if you need to specify other remotes, please use `remote=xxx`. For example:
  - `GitLink remote=upstream`: copy `blob` url to clipboard for `upstream`.
  - `GitLink! blame remote=upstream`: open `blame` url in browser for `upstream`.

### API

> [!NOTE]
>
> Highly recommend reading [Customize Urls](#customize-urls) before this section, which helps understanding the router design of this plugin.

You can also use the `link` API to generate git permlink:

```lua
--- @alias gitlinker.Linker {remote_url:string,protocol:string?,username:string?,password:string?,host:string,port:string?,org:string?,user:string?,repo:string,rev:string,file:string,lstart:integer,lend:integer,file_changed:boolean,default_branch:string?,current_branch:string?}
--- @alias gitlinker.Router fun(lk:gitlinker.Linker):string?
--- @alias gitlinker.Action fun(url:string):any
--- @param opts {router_type:string?,router:gitlinker.Router?,action:gitlinker.Action?,lstart:integer?,lend:integer?,message:boolean?,highlight_duration:integer?,remote:string?}?
require("gitlinker").link(opts)
```

#### Parameters:

- `opts`: (Optional) lua table that contains below fields:

  - `router_type`: Which router type should this API use. By default is `nil`, means `browse`. It has below builtin options:

    - `browse`
    - `blame`
    - `default_branch`

  - `router`: Which router implementation should this API use. By default is `nil`, it uses the configured router implementations while this plugin is been setup (see [Configuration](#configuration)). You can **_dynamically_** overwrite the generate behavior by pass a router in this field.

    > Once set this field, you will get full control of generating the url, and `router_type` field will no longer take effect.
    >
    > Please refer to [`gitlinker.Router`](#gitlinkerrouter) for more details.

  - `action`: What action should this API behave. By default is `nil`, this API will copy the generated link to clipboard. It has below builtin options:

    - `require("gitlinker.actions").clipboard`: Copy generated link to clipboard.
    - `require("gitlinker.actions").system`: Open generated link in browser.

    > Please refer to [`gitlinker.Action`](#gitlinkeraction) for more details.

  - `lstart`/`lend`: Visual selected line range, e.g. start & end line numbers. By default both are `nil`, it will automatically try to find user selected line range. You can also overwrite these two fields to force the line numbers in generated url.
  - `message`: Whether print message in nvim command line. By default it uses the configured value while this plugin is been setup (see [Configuration](#configuration)). You can also overwrite this field to change the configured behavior.
  - `highlight_duration`: How long (milliseconds) to highlight the line range. By default it uses the configured value while this plugin is been setup (see [Configuration](#configuration)). You can also overwrite this field to change the configured behavior.
  - `remote`: Specify the git remote. By default is `nil`, it uses the first detected git remote (usually it's `origin`).

##### `gitlinker.Router`

`gitlinker.Router` is a lua function that implements a router for a git host. It use below function signature:

```lua
function(lk:gitlinker.Linker):string?
```

**Parameters:**

- `lk`: Lua table that presents the `gitlinker.Linker` data type. It contains all the information (fields) you need to generate a git link, e.g. the `protocol`, `host`, `username`, `path`, `rev`, etc.

  > Please refer to [Customize Urls - Lua Function](#lua-function) for more details.

**Returns:**

- It returns the generated link as a `string` type, if success.
- It returns `nil`, if failed.

##### `gitlinker.Action`

`gitlinker.Action` is a lua function that do some operations with a generated git link. It use below function signature:

```lua
function(url:string):any
```

**Parameters:**

- `url`: The generated git link. For example: https://codeberg.org/linrongbin16/gitlinker.nvim/src/commit/a570f22ff833447ee0c58268b3bae4f7197a8ad8/LICENSE#L4-L7.

For now we have below builtin actions:

- `require("gitlinker.actions").clipboard`: Copy url to clipboard.
- `require("gitlinker.actions").system`: Open url in browser.

If you only need to get the generated url, instead of do some actions, you can pass a callback function to accept the url:

```lua
require("gitlinker").link({
  action = function(url)
    print("generated url:" .. vim.inspect(url))
  end,
})
```

> The `link` API is running in async way because it uses lua coroutine to avoid editor blocking.

### Recommended Key Mappings

<details>
<summary><i>Click here to see lua scripts with vim command</i></summary>
<br/>

```lua
-- with vim command:

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
-- default branch
vim.keymap.set(
  {"n", 'v'},
  "<leader>gd",
  "<cmd>GitLink default_branch<cr>",
  { silent = true, noremap = true, desc = "Copy default branch link to clipboard" }
)
vim.keymap.set(
  {"n", 'v'},
  "<leader>gD",
  "<cmd>GitLink! default_branch<cr>",
  { silent = true, noremap = true, desc = "Open default branch link in browser" }
)

</details>

<details>
<summary><i>Click here to see lua scripts with lua api</i></summary>
<br/>

-- with lua api:
-- browse
vim.keymap.set(
  {"n", 'v'},
  "<leader>gl",
  require("gitlinker").link,
  { silent = true, noremap = true, desc = "GitLink" }
)
vim.keymap.set(
  {"n", 'v'},
  "<leader>gL",
  function()
    require("gitlinker").link({ action = require("gitlinker.actions").system })
  end,
  { silent = true, noremap = true, desc = "GitLink!" }
)
-- blame
vim.keymap.set(
  {"n", 'v'},
  "<leader>gb",
  function()
    require("gitlinker").link({ router_type = "blame" })
  end,
  { silent = true, noremap = true, desc = "GitLink blame" }
)
vim.keymap.set(
  {"n", 'v'},
  "<leader>gB",
  function()
    require("gitlinker").link({
      router_type = "blame",
      action = require("gitlinker.actions").system,
    })
  end,
  { silent = true, noremap = true, desc = "GitLink! blame" }
)
-- default branch
vim.keymap.set(
  {"n", 'v'},
  "<leader>gd",
  function()
    require("gitlinker").link({ router_type = "default_branch" })
  end,
  { silent = true, noremap = true, desc = "GitLink default_branch" }
)
vim.keymap.set(
  {"n", 'v'},
  "<leader>gD",
  function()
    require("gitlinker").link({
      router_type = "default_branch",
      action = require("gitlinker.actions").system,
    })
  end,
  { silent = true, noremap = true, desc = "GitLink! default_branch" }
)
```

</details>

## Configuration

```lua
require('gitlinker').setup(opts)
```

The `opts` is an optional lua table that override the default options.

For complete default options, please see `Defaults` in [configs.lua](https://github.com/linrongbin16/gitlinker.nvim/blob/master/lua/gitlinker/configs.lua).

### Customize Urls

> [!NOTE]
>
> Please refer to [Git Protocols](https://git-scm.com/book/en/v2/Git-on-the-Server-The-Protocols) and [giturlparser](https://github.com/linrongbin16/giturlparser.lua?tab=readme-ov-file#features) for better understanding git url.

#### String Template

> [!NOTE]
>
> Please refer to `Defaults.router` in [configs.lua](https://github.com/linrongbin16/gitlinker.nvim/blob/master/lua/gitlinker/configs.lua) for more examples about string template.

To create customized urls for other git hosts, please bind the target git host name with a new router.

A router simply constructs the url string from below components (upper case with prefix `_A.`):

- `_A.PROTOCOL`: Network protocol before `://` delimiter, for example:
  - `https` in `https://github.com`.
  - `ssh` in `ssh://github.com`.
- `_A.USERNAME`: Optional user name component before `@` delimiter, for example:
  - `git` in `ssh://git@github.com/linrongbin16/gitlinker.nvim.git`.
  - `myname` in `myname@github.com:linrongbin16/gitlinker.nvim.git` (**Note:** the ssh protocol `ssh://` can be omitted).
- `_A.PASSWORD`: Optional password component after `_A.USERNAME`, for example:
  - `mypass` in `myname:mypass@github.com:linrongbin16/gitlinker.nvim.git`.
  - `mypass` in `https://myname:mypass@github.com/linrongbin16/gitlinker.nvim.git`.
- `_A.HOST`: The host component, for example:
  - `github.com` in `https://github.com/linrongbin16/gitlinker.nvim` (**Note:** for http/https protocol, host ends with `/`).
  - `127.0.0.1` in `git@127.0.0.1:linrongbin16/gitlinker.nvim` (**Note:** for omitted ssh protocol, host ends with `:`, and cannot have `_A.PORT` component).
- `_A.PORT`: Optional port component after `_A.HOST` (**Note:** omitted ssh protocols cannot have `_A.PORT` component), for example:
  - `22` in `https://github.com:22/linrongbin16/gitlinker.nvim`.
  - `123456` in `https://127.0.0.1:123456/linrongbin16/gitlinker.nvim`.
- `_A.PATH`: All the other parts in the output of the `git remote get-url origin`, for example:
  - `/linrongbin16/gitlinker.nvim.git` in `https://github.com/linrongbin16/gitlinker.nvim.git`.
  - `linrongbin16/gitlinker.nvim.git` in `git@github.com:linrongbin16/gitlinker.nvim.git`.
- `_A.REV`: Git commit, for example:
  - `a009dacda96756a8c418ff5fa689999b148639f6` in `https://github.com/linrongbin16/gitlinker.nvim/blob/a009dacda96756a8c418ff5fa689999b148639f6/lua/gitlinker/git.lua?plain=1#L3`.
- `_A.FILE`: Relative file path, for example:
  - The `lua/gitlinker/routers.lua` in `https://github.com/linrongbin16/gitlinker.nvim/blob/master/lua/gitlinker/routers.lua`.
- `_A.LSTART`/`_A.LEND`: Start/end line number, for example:
  - `5`/`13` in `https://github.com/linrongbin16/gitlinker.nvim/blob/master/lua/gitlinker/routers.lua#L5-L13`.

There're 2 more sugar components derived from `_A.PATH`:

- `_A.REPO`: The last part after the last slash (`/`) in `_A.PATH`, with around slashes been removed (and the `.git` suffix is been removed for easier writing), for example:
  - `gitlinker.nvim` in `https://github.com/linrongbin16/gitlinker.nvim.git`.
  - `neovim` in `git@192.168.0.1:path/to/the/neovim.git`.
- `_A.ORG`: All the other parts before `_A.REPO`, with around slashes been removed, for example:
  - `linrongbin16` in `https://github.com/linrongbin16/gitlinker.nvim.git`.
  - `path/to/the` in `https://github.com/path/to/the/repo.git`.

> [!IMPORTANT]
>
> The `_A.ORG` component can be empty when the `_A.PATH` contains only 1 slash (`/`), for example: the `_A.ORG` in `ssh://git@host.xyz/repo.git` is empty.

There're 2 more sugar components for git branches:

- `_A.DEFAULT_BRANCH`: Default branch retrieved from `git rev-parse --abbrev-ref origin/HEAD`, for example:
  - `master` in `https://github.com/ruifm/gitlinker.nvim/blob/master/lua/gitlinker/routers.lua#L37-L156`.
  - `main` in `https://github.com/linrongbin16/commons.nvim/blob/main/lua/commons/uv.lua`.
- `_A.CURRENT_BRANCH`: Current branch retrieved from `git rev-parse --abbrev-ref HEAD`, for example:
  - `feat-router-types`.

For example you can customize the line numbers in form `?&line=1&lines-count=2` like this:

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

The template string use curly braces `{}` to contain lua scripts, and evaluate via [luaeval()](https://neovim.io/doc/user/lua.html#lua-eval) (while the error message can be confusing if there's any syntax issue).

#### Lua Function

> [!NOTE]
>
> Please refer to [routers.lua](https://github.com/linrongbin16/gitlinker.nvim/blob/master/lua/gitlinker/routers.lua) for builtin routers implementation.

You can also bind a lua function to it, which accepts a lua table parameter that contains the same fields, but in lower case, without the prefix `_A.`:

- `protocol`
- `username`
- `password`
- `host`
- `port`
- `path`
- `rev`
- `file`
- `lstart`/`lend`

The 2 derived components are:

- `org`
- `repo`: **Note:** the `.git` suffix is not omitted.

The 2 branch components are:

- `default_branch`
- `current_branch`

Thus you can use below lua function to implement your router:

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

There are some pre-defined lua apis in `gitlinker.routers` that you can use:

- `github_browse`/`github_blame`: for github.com.
- `gitlab_browse`/`gitlab_blame`: for gitlab.com.
- `bitbucket_browse`/`bitbucket_blame`: for bitbucket.org.
- `codeberg_browse`/`codeberg_blame`: for codeberg.org.
- `samba_browse`: for git.samba.org (blame not support).

For example if you need to bind a github enterprise domain, you can use:

```lua
require('gitlinker').setup({
  router = {
    browse = {
      ["^github%.your%.host"] = require('gitlinker.routers').github_browse,
    },
    blame = {
      ["^github%.your%.host"] = require('gitlinker.routers').github_blame,
    },
  }
})
```

### Create Your Own Router

You can even create your own router (e.g. use the same engine with `browse`/`blame`), for example create the `file_only` router type (generate link without line numbers):

```lua
require("gitlinker").setup({
  router = {
    file_only = {
      ["^github%.com"] = "https://github.com/"
        .. "{_A.ORG}/"
        .. "{_A.REPO}/blob/"
        .. "{_A.REV}/"
        .. "{_A.FILE}"
    },
  },
})
```

Then use it just like `browse`:

```vim
GitLink file_only
GitLink! file_only
```

### Highlight Group

| Highlight Group                  | Default Group | Description                          |
| -------------------------------- | ------------- | ------------------------------------ |
| NvimGitLinkerHighlightTextObject | Search        | highlight line ranges when copy/open |

## Development

To develop the project and make PR, please setup with:

- [lua_ls](https://github.com/LuaLS/lua-language-server).
- [stylua](https://github.com/JohnnyMorganz/StyLua).
- [selene](https://github.com/Kampfkarren/selene).

To run unit tests, please install below dependencies:

- [vusted](https://github.com/notomo/vusted).

Then test with `vusted ./spec`.

## Contribute

Please open [issue](https://github.com/linrongbin16/gitlinker.nvim/issues)/[PR](https://github.com/linrongbin16/gitlinker.nvim/pulls) for anything about gitlinker.nvim.

Like gitlinker.nvim? Consider

[![Github Sponsor](https://img.shields.io/badge/-Sponsor%20Me%20on%20Github-magenta?logo=github&logoColor=white)](https://github.com/sponsors/linrongbin16)
[![Wechat Pay](https://img.shields.io/badge/-Tip%20Me%20on%20WeChat-brightgreen?logo=wechat&logoColor=white)](https://linrongbin16.github.io/sponsor)
[![Alipay](https://img.shields.io/badge/-Tip%20Me%20on%20Alipay-blue?logo=alipay&logoColor=white)](https://linrongbin16.github.io/sponsor)
