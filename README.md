<!-- markdownlint-disable MD001 MD013 MD034 MD033 -->

# gitlinker.nvim

<p>
<a href="https://github.com/neovim/neovim/releases/tag/v0.12.0"><img alt="Neovim" src="https://img.shields.io/badge/require-0.12%2B-blue" /></a>
<a href="https://github.com/linrongbin16/gitlinker.nvim/actions/workflows/ci.yml"><img alt="ci.yml" src="https://img.shields.io/github/actions/workflow/status/linrongbin16/gitlinker.nvim/ci.yml?label=ci" /></a>
</p>

> Maintained fork of [ruifm's gitlinker](https://github.com/ruifm/gitlinker.nvim), refactored with bug fixes, ssh host alias support, blame support and other improvements. Inspired by [tpope/vim-fugitive](https://github.com/tpope/vim-fugitive)'s `:GBrowse`.

Generate sharable git permalinks, with line ranges, straight from Neovim. Put the cursor on a line (or select a range), run `:GitLink`, and the url of that exact blob on the git host website lands in your clipboard:

Here is an example of git permlink: https://github.com/neovim/neovim/blob/2e156a3b7d7e25e56b03683cc6228c531f4c91ef/src/nvim/main.c#L137-L156

https://github.com/linrongbin16/gitlinker.nvim/assets/6496887/d3e425a5-cf08-487f-badc-d393ca9dda2f

For now supported platforms are:

- https://github.com/
- https://gitlab.com/
- https://bitbucket.org/
- https://codeberg.org/
- https://git.samba.org/

PRs are welcomed for other git host websites!

## Features

- Provide `GitLink` command, not default key mappings.
- Support Windows and WSL2 platforms.
- Support git blame, default branch and current branch.
- Respect ssh host alias.
- Add `?plain=1` for markdown files.
- Fully customizable [git url](https://git-scm.com/book/en/v2/Git-on-the-Server-The-Protocols) generation.

## Requirements

- Neovim &ge; 0.12.
- [git](https://git-scm.com/) available in `$PATH`.
- [ssh](https://www.openssh.com/) (optional, used to resolve ssh host aliases from `~/.ssh/config`).
- [wslu](https://packages.ubuntu.com/search?keywords=wslu) (optional, used to open browser from Windows wsl2).

## Installation

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
require("lazy").setup({
  {
    "linrongbin16/gitlinker.nvim",
    cmd = "GitLink",
    opts = {},
    keys = {
      {
        "<leader>gy",
        "<cmd>GitLink<cr>",
        mode = { "n", "v" },
        desc = "Copy git permalink",
      },
      {
        "<leader>gY",
        "<cmd>GitLink!<cr>",
        mode = { "n", "v" },
        desc = "Open git permalink",
      },
    },
  },
})
```

### [pckr.nvim](https://github.com/lewis6991/pckr.nvim)

```lua
return require("pckr").add({
  {
    "linrongbin16/gitlinker.nvim",
    config = function()
      require("gitlinker").setup()
    end,
  },
})
```

### [vim.pack](https://neovim.io/doc/user/pack.html#vim.pack)

```lua
vim.pack.add({ "https://github.com/linrongbin16/gitlinker.nvim" })
```

### Manual

```sh
git clone https://github.com/linrongbin16/gitlinker.nvim \
  ~/.local/share/nvim/site/pack/plugins/start/gitlinker.nvim
```

## Usage

### Command

`:GitLink` copies the permalink of the current line, or of the visual selection, to the clipboard:

- `:GitLink`: `browse` url, copied to the clipboard, it is the optional default sub command.
- `:GitLink blame`: `blame` url, copied to the clipboard.
- `:GitLink default_branch`: url pinned to the default branch instead of a commit id.
- `:GitLink current_branch`: url pinned to the current branch.
- `:GitLink!`: same url as `:GitLink`, but opened in the browser instead of copied. For example: `:GitLink! blame`.

The command takes a range and completes router types on `<Tab>`:

```vim
:5,8GitLink
:'<,'>GitLink
```

### Router Types

A router type is a set of implementations bound to different git host websites, it is not tied to one host. Bind your own git host under any of these names, or invent a new name entirely, see [Create Your Own Router](#create-your-own-router).

Each router type generates a different kind of url, and each host spells it differently:

| Router type        | github.com                           | gitlab.com                   | bitbucket.org                   | codeberg.org                                      | git.samba.org                                      |
| ------------------ | ------------------------------------ | ---------------------------- | ------------------------------- | ------------------------------------------------- | -------------------------------------------------- |
| `browse` (default) | `/blob/<rev>/<file>?plain=1#L12-L20` | `/blob/<rev>/<file>#L12-L20` | `/src/<rev>/<file>#lines-12:20` | `/src/commit/<rev>/<file>?display=source#L12-L20` | `?p=<org>/<repo>.git;a=blob;f=<file>;hb=<rev>#l12` |
| `blame`            | `/blame/<rev>/<file>`                | `/blame/<rev>/<file>`        | `/annotate/<rev>/<file>`        | `/blame/commit/<rev>/<file>`                      | not supported                                      |
| `default_branch`   | `/blob/<default>/<file>`             | `/blob/<default>/<file>`     | `/src/<default>/<file>`         | `/src/branch/<default>/<file>`                    | same as `browse`                                   |
| `current_branch`   | `/blob/<current>/<file>`             | `/blob/<current>/<file>`     | `/src/<current>/<file>`         | `/src/branch/<current>/<file>`                    | same as `browse`                                   |

Same file, four router types, on bitbucket.org:

- `browse`: https://bitbucket.org/osrf/gazebo/src/master/README.md#lines-1:5
- `blame`: https://bitbucket.org/osrf/gazebo/annotate/master/README.md#lines-1:5
- `default_branch`: https://bitbucket.org/osrf/gazebo/src/master/README.md#lines-1:5
- `current_branch`: https://bitbucket.org/osrf/gazebo/src/master/README.md#lines-1:5, where `master` is whatever branch is checked out

### Parameters

Three `key=value` arguments override what the current buffer would otherwise provide. They combine with any router type and with the bang:

- `remote=`: pick the git remote. For example `:GitLink remote=upstream`, `:GitLink! blame remote=upstream`.
- `file=`: pick the relative file path. For example `:GitLink file=lua/gitlinker.lua`, `:GitLink! blame file=README.md`.
- `rev=`: pick the revision, accepting anything `git rev-parse` understands (`HEAD`, `HEAD~3`, a branch, a tag, a short sha). For example `:GitLink rev=00b3f9a1`, `:GitLink! blame rev=v5.5.2`.

When a parameter is omitted, `remote` is detected from the branch upstream, `file` is the current buffer's path relative to the repository root, and `rev` is the closest revision that exists in the remote: the upstream first, then `HEAD`, then `HEAD~1` through `HEAD~50`. `file` is uri-encoded before it goes into the url, so `file=some dir/a b.lua` works.

With more than one git remote configured the plugin does not guess: it opens a picker (`Please select remote index:`) so you can choose one. Passing `remote=xxx` up front skips the picker, which is what you want in a key mapping.

### API

> [!NOTE]
>
> Reading [Customize Urls](#customize-urls) first helps, it explains the router design this API is built on.

```lua
--- @alias gitlinker.Linker {remote_url:string, protocol:string?, username:string?, password:string?, host:string, port:string?, org:string?, user:string?, repo:string, rev:string, file:string, lstart:integer, lend:integer, file_changed:boolean, default_branch:string?, current_branch:string?}
--- @alias gitlinker.Router fun(lk:gitlinker.Linker):string?
--- @alias gitlinker.Action fun(url:string):any
--- @param opts {router_type:string?, router:gitlinker.Router?, action:gitlinker.Action?, lstart:integer?, lend:integer?, message:boolean?, warn_on_file_change:boolean?, highlight_duration:integer?, remote:string?, file:string?, rev:string?}?
require("gitlinker").link(opts)
```

`:GitLink` is a thin user command wrapper around this API.

The call is **asynchronous and returns nothing**. Git runs in a coroutine and the url is delivered to your `action` callback a few event loop ticks later, so never expect a return value:

```lua
require("gitlinker").link({
  action = function(url)
    print("generated url: " .. url)
  end,
})
```

**Parameters:**

- `opts`: (Optional) lua table that contains below fields:
  - `router_type`: Which router type to use. Defaults to `browse`. It has below options:
    - `browse`
    - `blame`
    - `default_branch`
    - `current_branch`

  - `router`: Which router implementation to use. Defaults to the implementations registered by `setup()` (see [Configuration](#configuration)). Passing your own function overrides them for this call, see [`gitlinker.Router`](#gitlinkerrouter).

    > [!WARNING]
    >
    > Once this field is set, you have full control over url generation and `router_type` no longer takes effect.

  - `action`: What to do with the url. Defaults to `require("gitlinker.actions").clipboard`, see [`gitlinker.Action`](#gitlinkeraction).
    - `require("gitlinker.actions").clipboard`: copy the url to the clipboard.
    - `require("gitlinker.actions").open`: open the url in the browser.
    - Any other callable receives the url as its only argument.

  - `lstart`/`lend`: Line range, i.e. start and end line numbers. Defaults to the current line, or to the last visual selection when in visual mode.
  - `message`: Whether to print the url in the command line. Defaults to the configured value, see [Configuration](#configuration).
  - `warn_on_file_change`: Whether to print a warning message when file is changed. Defaults to the configured value, see [Configuration](#configuration).
  - `highlight_duration`: How long, in milliseconds, to highlight the linked line range. Defaults to the configured value. `0` disables the highlight.
  - `remote`: Specify the git remote. Defaults to the remote detected from the branch upstream.
  - `file`: Specify the relative file path. Defaults to the current buffer's name.
  - `rev`: Specify the revision. Defaults to the closest revision that exists in the remote.

#### `gitlinker.Router`

A lua function that implements a router for a git host website:

```lua
function(lk:gitlinker.Linker):string?
```

**Parameters:**

- `lk`: A `gitlinker.Linker` table holding everything needed to build the url: `remote_url`, `protocol`, `host`, `org`, `repo`, `rev`, `file`, `lstart`, `lend`, `file_changed`, and so on. See [Lua Function](#lua-function) for the full field list.

**Returns:**

- The generated url as a `string`, on success.
- `nil`, on failure.

#### `gitlinker.Action`

A lua function that consumes the generated url:

```lua
function(url:string):any
```

**Parameters:**

- `url`: The generated url, for example https://codeberg.org/forgejo/forgejo/src/commit/d191d25cb3b5082607780bdff89fc2353a92161b/README.md?display=source#L1-L5.

Two builtin actions are available:

- `require("gitlinker.actions").clipboard`: copy the url to the clipboard (`vim.fn.setreg("+", url)`).
- `require("gitlinker.actions").open`: open the url in the browser (`vim.ui.open(url)`).

To only print the url:

```lua
require("gitlinker").link({
  action = function(url)
    print("generated url: " .. url)
  end,
})
```

### Recommended Key Mappings

With vim commands:

```lua
local function cmdmap(lhs, cmd, desc)
  vim.keymap.set(
    { "n", "v" },
    lhs,
    "<cmd>" .. cmd .. "<cr>",
    { silent = true, desc = desc }
  )
end

-- browse
cmdmap("<leader>gl", "GitLink", "Copy git permalink")
cmdmap("<leader>gL", "GitLink!", "Open git permalink")

-- blame
cmdmap("<leader>gb", "GitLink blame", "Copy git blame link")
cmdmap("<leader>gB", "GitLink! blame", "Open git blame link")
```

With lua apis:

```lua
local gitlinker = require("gitlinker")
local actions = require("gitlinker.actions")

local function keymap(lhs, opts, desc)
  vim.keymap.set({ "n", "v" }, lhs, function()
    gitlinker.link(opts)
  end, { silent = true, desc = desc })
end

-- browse
keymap("<leader>gl", {}, "Copy git permalink")
keymap("<leader>gL", { action = actions.open }, "Open git permalink")

-- blame
keymap("<leader>gb", { router_type = "blame" }, "Copy git blame link")
keymap(
  "<leader>gB",
  { router_type = "blame", action = actions.open },
  "Open git blame link"
)
```

## Configuration

```lua
require("gitlinker").setup(opts)
```

`opts` is an optional lua table deep-merged over the defaults in [configs.lua](https://github.com/linrongbin16/gitlinker.nvim/blob/master/lua/gitlinker/configs.lua):

| Option                | Type                        | Default                                               | Description                                                                                      |
| --------------------- | --------------------------- | ----------------------------------------------------- | ------------------------------------------------------------------------------------------------ |
| `message`             | `boolean`                   | `true`                                                | Print the generated url in the command line.                                                     |
| `warn_on_file_change` | `boolean`                   | `true`                                                | Warn when the file changed since `<rev>` was committed, i.e. the line numbers may be stale.      |
| `highlight_duration`  | `integer`                   | `500`                                                 | Milliseconds to highlight the linked line range. `0` disables highlighting.                      |
| `command`             | `{name:string,desc:string}` | `{name="GitLink",desc="Generate git permanent link"}` | Name and description of the user command.                                                        |
| `router`              | `table`                     | see `Defaults.router`                                 | Router bindings, see [Customize Urls](#customize-urls).                                          |
| `debug`               | `boolean`                   | `false`                                               | Log at debug level instead of info.                                                              |
| `console_log`         | `boolean`                   | `true`                                                | Write logs to the command line.                                                                  |
| `file_log`            | `boolean`                   | `false`                                               | Also write logs to `stdpath("data")/gitlinker.log`.                                              |
| `clipboard_override`  | `function?` \| `false`      | `false`                                               | Custom clipboard writer used by `:GitLink`, see [Alternative Clipboard](#alternative-clipboard). |

Calling `setup()` is optional: the plugin file calls it with empty options when the plugin is loaded. Calling it a second time merges over the defaults again, so repeated calls are harmless.

### Customize Urls

> [!NOTE]
>
> Recommend reading [Git Protocols](https://git-scm.com/book/en/v2/Git-on-the-Server-The-Protocols) and [giturlparser](https://github.com/linrongbin16/giturlparser.lua?tab=readme-ov-file#features) for a better understanding of git urls.

You can bind a router to a private git host with a key-value pair, the key is a [lua pattern](https://www.lua.org/pil/20.2.html) (similar to [Regular expression](https://en.wikipedia.org/wiki/Regular_expression) but much worse), the value is either a [string template](#string-template) or a [lua function](#lua-function).

For example with GitHub Enterprise domain, you can add your own bindings:

```lua
require("gitlinker").setup({
  router = {
    browse = {
      -- map style: pattern as key, implementation as value
      ["^your%.github%.com"] = "https://your.github.com/"
        .. "{_A.ORG}/"
        .. "{_A.REPO}/blob/"
        .. "{_A.REV}/"
        .. "{_A.FILE}?plain=1"
        .. "#L{_A.LSTART}"
        .. "{(_A.LEND > _A.LSTART and ('-L' .. _A.LEND) or '')}",
    },
  },
})
```

In above example, the key `"^your%.github%.com"` matches the remote git domain `"your.github.com"`, and it will generate the git url with a string template, with multiple components: `_A.ORG`, `_A.REPO`, `_A.REV`, etc. See [string template](#string-template) for more details.

#### String Template

> [!NOTE]
>
> Please see `Defaults.router` in [configs.lua](https://github.com/linrongbin16/gitlinker.nvim/blob/master/lua/gitlinker/configs.lua) for more examples.

To create customized urls for other git hosts, bind the target git host to an implementation that constructs the url string from the components below, upper case with prefix `_A.`:

| Component           | Value                                                                                                                                                                                                                                                                                                                                                             | Example                                                                        |
| ------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------ |
| `_A.PROTOCOL`       | Protocol before the `://` delimiter.                                                                                                                                                                                                                                                                                                                              | `https` in `https://github.com/...`; empty for `git@github.com:org/repo.git`   |
| `_A.USERNAME`       | User name before the `@` delimiter.                                                                                                                                                                                                                                                                                                                               | `git` in `ssh://git@github.com/...`                                            |
| `_A.PASSWORD`       | Password after the user name.                                                                                                                                                                                                                                                                                                                                     | `mypass` in `https://myname:mypass@github.com/...`                             |
| `_A.HOST`           | Host name, without the brackets of an IPv6 literal.                                                                                                                                                                                                                                                                                                               | `github.com` in `https://github.com/...`, `::1` in `ssh://[::1]:2222/repo.git` |
| `_A.PORT`           | Port after the host.                                                                                                                                                                                                                                                                                                                                              | `2222` in `ssh://host.xyz:2222/...`                                            |
| `_A.ORG`            | Everything between the host and the repository name. This field can be empty when the remote url has no directory component, for example in `ssh://git@host.xyz/repo.git`, `_A.REPO` is `repo`, `_A.ORG` is empty. This field can also contain slashes, for example in `https://github.com/path/to/the/repo.git`, `_A.ORG` is `path/to/the`, `_A.REPO` is `repo`. | `linrongbin16` in `https://github.com/linrongbin16/gitlinker.nvim.git`         |
| `_A.REPO`           | Last path segment, with the `.git` suffix stripped.                                                                                                                                                                                                                                                                                                               | `gitlinker.nvim` in `https://github.com/linrongbin16/gitlinker.nvim.git`       |
| `_A.REV`            | Resolved commit id.                                                                                                                                                                                                                                                                                                                                               | `a009dacda96756a8c418ff5fa689999b148639f6`                                     |
| `_A.FILE`           | Relative file path, uri-encoded.                                                                                                                                                                                                                                                                                                                                  | `lua/gitlinker/git.lua`                                                        |
| `_A.LSTART`         | Start line number.                                                                                                                                                                                                                                                                                                                                                | `5`                                                                            |
| `_A.LEND`           | End line number, never smaller than `_A.LSTART`.                                                                                                                                                                                                                                                                                                                  | `13`                                                                           |
| `_A.DEFAULT_BRANCH` | Default branch, from `git rev-parse --abbrev-ref <remote>/HEAD`. Empty when git cannot tell.                                                                                                                                                                                                                                                                      | `master`, `main`                                                               |
| `_A.CURRENT_BRANCH` | Current branch, from `git rev-parse --abbrev-ref HEAD`. Empty when git cannot tell.                                                                                                                                                                                                                                                                               | `refactor-readme`                                                              |
| `_A.USER`           | Deprecated alias of `_A.ORG`, kept for compatibility.                                                                                                                                                                                                                                                                                                             | same as `_A.ORG`                                                               |

With these components you can, for example, rewrite the line range into the `?&lines=1&lines-count=2` form:

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
        .. "{_A.LEND > _A.LSTART and '&lines-count=' or ''}"
        .. "{_A.LEND > _A.LSTART and (_A.LEND - _A.LSTART + 1) or ''}",
    },
  },
})
```

The template string uses curly braces `{}` to hold lua expressions, evaluated through [luaeval()](https://neovim.io/doc/user/lua.html#lua-eval), so anything `luaeval` accepts works, including string literals. While error messages from a broken template can be confusing.

#### Lua Function

You can also implement a router as a lua function. It receives one table, with the same fields as the string template but lower case and without the `_A.` prefix:

| Field            | Type      | Description                                                               |
| ---------------- | --------- | ------------------------------------------------------------------------- |
| `remote_url`     | `string`  | The url of the remote, as printed by `git remote get-url <remote>`.       |
| `protocol`       | `string?` | Protocol before the `://` delimiter.                                      |
| `username`       | `string?` | User name before the `@` delimiter.                                       |
| `password`       | `string?` | Password after the user name.                                             |
| `host`           | `string`  | Host name, without the brackets of an IPv6 literal.                       |
| `port`           | `string?` | Port after the host.                                                      |
| `org`            | `string?` | Everything between the host and the repository name.                      |
| `repo`           | `string`  | Repository name, **with** the `.git` suffix kept.                         |
| `rev`            | `string`  | Resolved commit id.                                                       |
| `file`           | `string`  | Relative file path, uri-encoded.                                          |
| `lstart`         | `integer` | Start line number.                                                        |
| `lend`           | `integer` | End line number.                                                          |
| `file_changed`   | `boolean` | Whether the file changed since `rev`, i.e. the line numbers may be stale. |
| `default_branch` | `string?` | Default branch.                                                           |
| `current_branch` | `string?` | Current branch.                                                           |
| `user`           | `string?` | Deprecated alias of `org`, kept for compatibility.                        |

The previous example, implemented as a function:

```lua
--- @param s string
--- @param t string
--- @return boolean
local function string_endswith(s, t)
  return string.len(s) >= string.len(t) and string.sub(s, #s - #t + 1) == t
end

--- @param lk gitlinker.Linker
--- @return string
local function your_router(lk)
  local builder = "https://"
  -- host
  builder = builder .. lk.host .. "/"
  -- org
  builder = builder .. lk.org .. "/"
  -- repo
  local repo = lk.repo
  if string_endswith(repo, ".git") then
    repo = repo:sub(1, #repo - 4)
  end
  builder = builder .. repo .. "/"
  -- blob and rev
  builder = builder .. "blob/" .. lk.rev .. "/"
  -- file
  builder = builder .. lk.file
  -- line range
  builder = builder .. string.format("?&lines=%d", lk.lstart)
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

A github enterprise host is a common case, since it speaks the same url structure as `github.com`:

```lua
--- @param lk gitlinker.Linker
--- @return string
local function github_browse(lk)
  local repo = (lk.repo or ""):gsub("%.git$", "")
  local location = string.format("%s?plain=1#L%d", lk.file, lk.lstart)
  if lk.lend > lk.lstart then
    location = location .. string.format("-L%d", lk.lend)
  end
  return table.concat({
    "https://" .. lk.host,
    lk.org,
    repo,
    "blob",
    lk.rev,
    location,
  }, "/")
end

--- @param lk gitlinker.Linker
--- @return string
local function github_blame(lk)
  local repo = (lk.repo or ""):gsub("%.git$", "")
  local location = string.format("%s?plain=1#L%d", lk.file, lk.lstart)
  if lk.lend > lk.lstart then
    location = location .. string.format("-L%d", lk.lend)
  end
  return table.concat({
    "https://" .. lk.host,
    lk.org,
    repo,
    "blame",
    lk.rev,
    location,
  }, "/")
end

require("gitlinker").setup({
  router = {
    browse = {
      ["^github%.your%.host"] = github_browse,
    },
    blame = {
      ["^github%.your%.host"] = github_blame,
    },
  },
})
```

### Create Your Own Router

Routers use the same engine everywhere, so a new router type is just a new key in `router`. This one, `file_only`, generates urls without line numbers:

```lua
require("gitlinker").setup({
  router = {
    file_only = {
      ["^github%.com"] = "https://github.com/"
        .. "{_A.ORG}/"
        .. "{_A.REPO}/blob/"
        .. "{_A.REV}/"
        .. "{_A.FILE}",
    },
  },
})
```

Use it like any builtin router:

```vim
GitLink file_only
GitLink! file_only
```

### Alternative Clipboard

You can define your own clipboard function during setup.

For example, to copy the url over a remote ssh session with an OSC52-compatible terminal, either a plugin or the built-in support works:

With [nvim-osc52](https://github.com/ojroques/nvim-osc52), whose `copy` already takes the text as its only argument:

```lua
require("gitlinker").setup({
  clipboard_override = require("osc52").copy,
})
```

With Neovim's built-in OSC52 support, which is a curried function returning the actual writer:

```lua
require("gitlinker").setup({
  clipboard_override = function(url)
    require("vim.ui.clipboard.osc52").copy("+")({ url })
  end,
})
```

### Highlight Group

| Highlight Group                  | Default Group | Description                          |
| -------------------------------- | ------------- | ------------------------------------ |
| NvimGitLinkerHighlightTextObject | Search        | highlight line ranges when copy/open |

The group is created only when `highlight_duration` is greater than `0`, and only if it does not exist yet, so you can define your own colors before the plugin loads.

## Development

To develop the project and make a PR, please set up:

- [lua_ls](https://github.com/LuaLS/lua-language-server).
- [stylua](https://github.com/JohnnyMorganz/StyLua).
- [selene](https://github.com/Kampfkarren/selene).

To run unit tests, please use `make test`.

## Contribute

Please open [issue](https://github.com/linrongbin16/gitlinker.nvim/issues)/[PR](https://github.com/linrongbin16/gitlinker.nvim/pulls) for anything about gitlinker.nvim.

## License

[GPL-3.0](./LICENSE) &copy; [linrongbin16](https://github.com/linrongbin16)
