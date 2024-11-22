# gitlinker.nvim

<p>
<a href="https://github.com/neovim/neovim/releases/"><img alt="Neovim" src="https://img.shields.io/badge/require-stable-blue" /></a>
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

- https://github.com/
- https://gitlab.com/
- https://bitbucket.org/
- https://codeberg.org/
- https://git.samba.org/

PRs are welcomed for other git host websites!

## Table of Contents

- [Break Changes & Updates](#break-changes--updates)
- [Requirements](#requirements)
- [Installation](#installation)
- [Usage](#usage)
  - [Command](#command)
    - [Multiple Remotes](#multiple-remotes)
    - [Relative File Path](#relative-file-path)
    - [Commit ID](#commit-id)
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
   - Blame support.
   - Full [git protocols](https://git-scm.com/book/en/v2/Git-on-the-Server-The-Protocols) support.
   - Respect ssh host alias.
   - Add `?plain=1` for markdown files.
3. Improvements:
   - Use git `stderr` output as error message.
   - Async child process IO via coroutine and `uv.spawn`.
   - No third-party dependencies.

## Requirements

> [!NOTE]
>
> This plugin always supports the latest stable and (possibly) nightly Neovim version.

- Neovim &ge; 0.10.
- [git](https://git-scm.com/).
- [ssh](https://www.openssh.com/) (optional for resolve ssh host alias).
- [wslview](https://github.com/wslutilities/wslu) (optional for open browser from Windows wsl2).

## Installation

<details>
<summary><b>With <a href="https://github.com/folke/lazy.nvim">lazy.nvim</a></b></summary>

```lua
require("lazy").setup({
  {
    "linrongbin16/gitlinker.nvim",
    cmd = "GitLink",
    opts = {},
    keys = {
      { "<leader>gy", "<cmd>GitLink<cr>", mode = { "n", "v" }, desc = "Yank git link" },
      { "<leader>gY", "<cmd>GitLink!<cr>", mode = { "n", "v" }, desc = "Open git link" },
    },
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

You can use the user command `GitLink` to generate a (perm)link to the git host website:

- `GitLink`: copy the `/blob` url to clipboard.
- `GitLink blame`: copy the `/blame` url to clipboard.
- `GitLink default_branch`: copy the `/main` or `/master` url to clipboard.
- `GitLink current_branch`: copy the current branch url to clipboard.

> [!NOTE]
>
> Add `!` after the command (`GitLink!`) to directly open the url in browser.

There're several **router types**:

- `browse`: generate the `/blob` url (default).
- `blame`: generate the `/blame` url.
- `default_branch`: generate the `/main` or `/master` url.
- `current_branch`: generate the current branch url.

> [!NOTE]
>
> A router type is a collection of multiple implementations binding on different git host websites, it works for any git hosts. For example the [bitbucket.org](https://bitbucket.org/):
>
> - `browse` generates the `/src` url (default): https://bitbucket.org/gitlinkernvim/gitlinker.nvim/src/dbf3922382576391fbe50b36c55066c1768b08b6/.gitignore#lines-9:14.
> - `blame` generates the `/annotate` url: https://bitbucket.org/gitlinkernvim/gitlinker.nvim/annotate/dbf3922382576391fbe50b36c55066c1768b08b6/.gitignore#lines-9:14.
> - `default_branch` generates the `/main` or `/master` url: https://bitbucket.org/gitlinkernvim/gitlinker.nvim/src/master/.gitignore#lines-9:14.
> - `current_branch` generates the current branch url: https://bitbucket.org/gitlinkernvim/gitlinker.nvim/src/feat-dev/.gitignore#lines-9:14.

#### Multiple Remotes

When there are multiple git remotes, please specify the remote with `remote=xxx` parameter. For example:

- `GitLink remote=upstream`: copy url for the `upstream` remote.
- `GitLink! blame remote=upstream`: open blame url for the `upstream` remote.

> [!NOTE]
>
> By default `GitLink` will use the first detected remote (usually it's `origin`).

#### Relative File Path

When the current buffer name is not the file name you want, please specify the target file path with `file=xxx` parameter. For example:

- `GitLink file=lua/gitlinker.lua`: copy url for the `lua/gitlinker.lua` file.
- `GitLink! blame file=README.md`: open blame url for the `README.md` file.

> [!NOTE]
>
> By default `GitLink` will use the current buffer's name.

#### Commit ID

When the current git repository's commit ID is not that one you want, please specify the target commit ID with `rev=xxx` parameter. For example:

- `GitLink rev=00b3f9a1`: copy url for the `00b3f9a1` commit ID.
- `GitLink! blame rev=00b3f9a1`: open blame url for the `00b3f9a1` commit ID.

> [!NOTE]
>
> By default `GitLink` will use the current git repository's commit ID.

### API

> [!NOTE]
>
> Highly recommend reading [Customize Urls](#customize-urls) before this section, which helps understanding the router design of this plugin.

<details>
<summary><i>Click here to see the details.</i></summary>
<br/>

You can also use the `link` API to generate git permlink:

```lua
--- @alias gitlinker.Linker {remote_url:string,protocol:string?,username:string?,password:string?,host:string,port:string?,org:string?,user:string?,repo:string,rev:string,file:string,lstart:integer,lend:integer,file_changed:boolean,default_branch:string?,current_branch:string?}
--- @alias gitlinker.Router fun(lk:gitlinker.Linker):string?
--- @alias gitlinker.Action fun(url:string):any
--- @param opts {router_type:string?,router:gitlinker.Router?,action:gitlinker.Action?,lstart:integer?,lend:integer?,message:boolean?,highlight_duration:integer?,remote:string?,file:string?,rev:string?}?
require("gitlinker").link(opts)
```

> The `GitLink` is actually just a user command wrapper on this API.

**Parameters:**

- `opts`: (Optional) lua table that contains below fields:

  - `router_type`: Which router type should use. By default is `browse` when not specified. It has below options:

    - `browse`
    - `blame`
    - `default_branch`
    - `current_branch`

  - `router`: Which router implementation should use. By default it uses the configured implementations when this plugin is been setup (see [Configuration](#configuration)). You can overwrite the configured behavior by passing your implementation to this field. Please see [`gitlinker.Router`](#gitlinkerrouter) for more details.

    > [!NOTE]
    >
    > Once set this field, you will get full control of generating the url, and `router_type` field will no longer take effect.

  - `action`: What action should do. By default it will copy the generated link to clipboard. It has below options, please see [`gitlinker.Action`](#gitlinkeraction) for more details.

    - `require("gitlinker.actions").clipboard`: Copy url to clipboard.
    - `require("gitlinker.actions").system`: Open url in browser.

  - `lstart`/`lend`: Line range, i.e. start and end line numbers. By default it uses the current line or visual selections. You can also overwrite them to specify the line numbers.
  - `message`: Whether print message in command line. By default it uses the configured value while this plugin is been setup (see [Configuration](#configuration)). You can overwrite the configured behavior by passing your option to this field.
  - `highlight_duration`: How long (in milliseconds) to highlight the line range. By default it uses the configured value while this plugin is been setup (see [Configuration](#configuration)). You can overwrite the configured behavior by passing your option to this field.
  - `remote`: Specify the git remote. By default it uses the first detected git remote (usually it's `origin`).
  - `file`: Specify the relative file path. By default it uses the current buffer's name.
  - `rev`: Specify the git commit ID. By default it uses the current git repository's commit ID.

#### `gitlinker.Router`

A lua function that implements a router for a git host website. It uses below function signature:

```lua
function(lk:gitlinker.Linker):string?
```

**Parameters:**

- `lk`: A lua table that presents the `gitlinker.Linker` data type. It contains all the information (fields) you need to generate a git link, e.g. the `protocol`, `host`, `username`, `path`, `rev`, etc. Please see [Customize Urls - Lua Function](#lua-function) for more details.

**Returns:**

- Returns the generated link as a `string` type, if success.
- Returns `nil`, if failed.

#### `gitlinker.Action`

A lua function that does some operations with the generated url. It uses below function signature:

```lua
function(url:string):any
```

**Parameters:**

- `url`: The generated url. For example: https://codeberg.org/linrongbin16/gitlinker.nvim/src/commit/a570f22ff833447ee0c58268b3bae4f7197a8ad8/LICENSE#L4-L7.

For now we have below builtin actions:

- `require("gitlinker.actions").clipboard`: Copy url to clipboard.
- `require("gitlinker.actions").system`: Open url in browser.

If you only need to print the generated url, you can pass a callback function to consume:

```lua
require("gitlinker").link({
  action = function(url)
    print("generated url:" .. vim.inspect(url))
  end,
})
```

</details>

### Recommended Key Mappings

<details>
<summary><i>Click here to see mappings with user commands.</i></summary>
<br/>

```lua
-- with vim command:

-- browse
vim.keymap.set(
  {"n", 'v'},
  "<leader>gl",
  "<cmd>GitLink<cr>",
  { silent = true, noremap = true, desc = "Yank git permlink" }
)
vim.keymap.set(
  {"n", 'v'},
  "<leader>gL",
  "<cmd>GitLink!<cr>",
  { silent = true, noremap = true, desc = "Open git permlink" }
)
-- blame
vim.keymap.set(
  {"n", 'v'},
  "<leader>gb",
  "<cmd>GitLink blame<cr>",
  { silent = true, noremap = true, desc = "Yank git blame link" }
)
vim.keymap.set(
  {"n", 'v'},
  "<leader>gB",
  "<cmd>GitLink! blame<cr>",
  { silent = true, noremap = true, desc = "Open git blame link" }
)
-- default branch
vim.keymap.set(
  {"n", 'v'},
  "<leader>gd",
  "<cmd>GitLink default_branch<cr>",
  { silent = true, noremap = true, desc = "Copy default branch link" }
)
vim.keymap.set(
  {"n", 'v'},
  "<leader>gD",
  "<cmd>GitLink! default_branch<cr>",
  { silent = true, noremap = true, desc = "Open default branch link" }
)
-- default branch
vim.keymap.set(
  {"n", 'v'},
  "<leader>gc",
  "<cmd>GitLink current_branch<cr>",
  { silent = true, noremap = true, desc = "Copy current branch link" }
)
vim.keymap.set(
  {"n", 'v'},
  "<leader>gD",
  "<cmd>GitLink! current_branch<cr>",
  { silent = true, noremap = true, desc = "Open current branch link" }
)
```

</details>

<details>
<summary><i>Click here to see mappings with lua apis.</i></summary>
<br/>

```lua
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
-- default branch
vim.keymap.set(
  {"n", 'v'},
  "<leader>gc",
  function()
    require("gitlinker").link({ router_type = "current_branch" })
  end,
  { silent = true, noremap = true, desc = "GitLink current_branch" }
)
vim.keymap.set(
  {"n", 'v'},
  "<leader>gC",
  function()
    require("gitlinker").link({
      router_type = "current_branch",
      action = require("gitlinker.actions").system,
    })
  end,
  { silent = true, noremap = true, desc = "GitLink! current_branch" }
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
> Recommend reading [Git Protocols](https://git-scm.com/book/en/v2/Git-on-the-Server-The-Protocols) and [giturlparser](https://github.com/linrongbin16/giturlparser.lua?tab=readme-ov-file#features) for better understanding git urls.

#### String Template

> [!NOTE]
>
> Please see `Defaults.router` in [configs.lua](https://github.com/linrongbin16/gitlinker.nvim/blob/master/lua/gitlinker/configs.lua) for more examples.

To create customized urls for other git hosts, please bind the target git host name with a new implementation, which simply constructs the url string from below components (upper case with prefix `_A.`):

- `_A.PROTOCOL`: Network protocol before `://` delimiter. For example:
  - `https` in `https://github.com`.
  - `ssh` in `ssh://github.com`.
- `_A.USERNAME`: Optional user name component before `@` delimiter. For example:
  - `git` in `ssh://git@github.com/linrongbin16/gitlinker.nvim.git`.
  - `myname` in `myname@github.com:linrongbin16/gitlinker.nvim.git` (**Note:** the ssh protocol `ssh://` is omitted in this case).
- `_A.PASSWORD`: Optional password component after `_A.USERNAME`. For example:
  - `mypass` in `myname:mypass@github.com:linrongbin16/gitlinker.nvim.git`.
  - `mypass` in `https://myname:mypass@github.com/linrongbin16/gitlinker.nvim.git`.
- `_A.HOST`: The host component. For example:
  - `github.com` in `https://github.com/linrongbin16/gitlinker.nvim` (**Note:** for http/https protocol, the host ends with `/`).
  - `127.0.0.1` in `git@127.0.0.1:linrongbin16/gitlinker.nvim` (**Note:** for _omitted_ ssh protocol, the host ends with `:`, and it cannot have `_A.PORT` component).
- `_A.PORT`: Optional port component after `_A.HOST` (**Note:** omitted ssh protocols cannot have `_A.PORT` component). For example:
  - `22` in `https://github.com:22/linrongbin16/gitlinker.nvim`.
  - `123456` in `https://127.0.0.1:123456/linrongbin16/gitlinker.nvim`.
- `_A.PATH`: Path component, i.e. all the other parts in the output of the `git remote get-url origin`. For example:
  - `/linrongbin16/gitlinker.nvim.git` in `https://github.com/linrongbin16/gitlinker.nvim.git`.
  - `linrongbin16/gitlinker.nvim.git` in `git@github.com:linrongbin16/gitlinker.nvim.git` (**Note:** for ssh protocol, the `:` before the path component doesn't belong to it).
- `_A.REV`: Git commit ID. For example:
  - `a009dacda96756a8c418ff5fa689999b148639f6` in `https://github.com/linrongbin16/gitlinker.nvim/blob/a009dacda96756a8c418ff5fa689999b148639f6/lua/gitlinker/git.lua?plain=1#L3`.
- `_A.FILE`: Relative file path. For example:
  - `lua/gitlinker/routers.lua` in `https://github.com/linrongbin16/gitlinker.nvim/blob/master/lua/gitlinker/routers.lua`.
- `_A.LSTART`/`_A.LEND`: Start/end line number. For example:
  - `5`/`13` in `https://github.com/linrongbin16/gitlinker.nvim/blob/master/lua/gitlinker/routers.lua#L5-L13`.

There're 2 more sugar components derived from `_A.PATH`:

- `_A.REPO`: The last part after the last slash (`/`) in `_A.PATH` (around slashes are removed, and the `.git` suffix is been removed for easier writing). For example:
  - `gitlinker.nvim` in `https://github.com/linrongbin16/gitlinker.nvim.git`.
  - `neovim` in `git@192.168.0.1:path/to/the/neovim.git`.
- `_A.ORG`: All the previous parts before `_A.REPO` (around slashes are removed). For example:
  - `linrongbin16` in `https://github.com/linrongbin16/gitlinker.nvim.git`.
  - `path/to/the` in `https://github.com/path/to/the/repo.git`.

> [!IMPORTANT]
>
> The `_A.ORG` component can be empty if `_A.PATH` only contains 1 slash (`/`). For example `_A.ORG` in `ssh://git@host.xyz/repo.git` is empty, while `_A.REPO` is `repo`.

There're 2 more sugar components for git branches:

- `_A.DEFAULT_BRANCH`: Default branch retrieved from `git rev-parse --abbrev-ref origin/HEAD`. For example:
  - `master` in `https://github.com/ruifm/gitlinker.nvim/blob/master/lua/gitlinker/routers.lua#L37-L156`.
  - `main` in `https://github.com/linrongbin16/commons.nvim/blob/main/lua/commons/uv.lua`.
- `_A.CURRENT_BRANCH`: Current branch retrieved from `git rev-parse --abbrev-ref HEAD`. For example:
  - `feat-router-types` in `https://github.com/ruifm/gitlinker.nvim/blob/feat-router-types/lua/gitlinker/routers.lua#L37-L156`.

With above components, you can customize the line numbers (for example) in form `?&line=1&lines-count=2` like this:

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

The template string use curly braces `{}` to contain lua scripts, and evaluate via [luaeval()](https://neovim.io/doc/user/lua.html#lua-eval) (the error message can be confusing if there's any syntax issue).

#### Lua Function

> [!NOTE]
>
> Please see [routers.lua](https://github.com/linrongbin16/gitlinker.nvim/blob/master/lua/gitlinker/routers.lua) for more examples.

You can also implement the router with a lua function. The function accepts only 1 lua table as its parameter, which contains the same fields as string template, but in lower case, without the prefix `_A.`:

- `protocol`
- `username`
- `password`
- `host`
- `port`
- `path`
- `rev`
- `file`
- `lstart`/`lend`

The 2 sugar components derived from `path` are:

- `org`
- `repo` (**Note:** the `.git` suffix is not omitted)

The 2 git branch components are:

- `default_branch`
- `current_branch`

Recall to previous use case (customize the line numbers in form `?&line=1&lines-count=2`), you can implement the router with below function:

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

There are some pre-defined APIs in `gitlinker.routers` that you can use:

- `github_browse`/`github_blame`: for https://github.com/.
- `gitlab_browse`/`gitlab_blame`: for https://gitlab.com/.
- `bitbucket_browse`/`bitbucket_blame`: for https://bitbucket.org/.
- `codeberg_browse`/`codeberg_blame`: for https://codeberg.org/.
- `samba_browse`: for https://git.samba.org/ (blame not support).

If you need to bind a github enterprise host, please use:

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

You can even create your own router (with the same engine). For example let's create the `file_only` router type, it generates url without line numbers:

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

Use it just like `browse`:

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
