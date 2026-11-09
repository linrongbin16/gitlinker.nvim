# 已知问题清单

本文档记录目前**仍然存在**的缺陷、风险与测试/CI 缺口。

**基线**：分支 `fix/normalize-line-range`，HEAD `fbed6e8`（在 `ed7e9ff`「fix(link): normalize the line range before the asynchronous link」之上）。
**验证环境**：Neovim `NVIM v0.12.6`（LuaJIT），Linux；`make test` 共 10 个 suite、**126** 用例全绿（types 21、configs 2、range 2、path 6、async 7、linker 5、git 14、root 4、highlight 17、gitlinker 48），`stylua --check lua spec` 通过，`selene --config selene.toml ./lua` 0 errors，本地 LuaLS 3.15.0 `--checklevel Warning` 无问题。

第一章的缺陷均在上表基线上**实际复现**过；第二、三章包含实测数据与代码审读结论，属于风险与改进项。复现用的临时仓库与脚本都在 `/tmp` 下（与本仓库无关），文中给出可直接重跑的步骤。

---

## 一、确认的功能性 Bug

### 1. 打印出来的 url 里 `%` 被双重转义

- **位置**：`lua/gitlinker.lua:321`（warn）、`lua/gitlinker.lua:326`（info）
- **代码**：
  ```lua
  log.warn(warning:gsub("%%", "%%%%"))
  log.info(url:gsub("%%", "%%%%") --[[@as string]])
  ```
- **现象**：文件路径含空格时，链接本身是 `some%20dir/a%20b.lua`，但命令行里显示成 `some%%20dir/a%%20b.lua`。
  ```
  实际 url : https://github.com/acme/demo/blob/072cfce/.../some%20dir/a%20b.lua?plain=1#L1
  打印出来: [gitlinker] .../some%%20dir/a%%20b.lua?plain=1#L1
  ```
- **原因**：`log.info`/`log.warn` 最终走 `vim.schedule(function() vim.notify(...) end)`。`vim.notify` 不按 `printf` 解释 `%`，只有 `nvim_echo`/`:echo` 才会。历史上的 `gsub` 大概是给已经不存在的 `nvim_echo` 消息路径用的，现在只剩副作用。
- **影响**：纯显示问题，剪贴板里的 url 正确。但只要用户怀疑链接错了（比如复制后对比命令行），就会被误导。
- **复现**：
  ```bash
  mkdir -p "some dir" && printf 'a\n' > "some dir/a b.lua"
  # 在仓库内的 buffer 里 :GitLink
  ```
- **修复建议**：删掉这两处 `:gsub("%%", "%%%%")`；若确实要支持 `nvim_echo`，改为只在 `nvim_echo` 分支转义。

### 2. `default_branch` 路由在分支名含 `/` 时截断

- **位置**：`lua/gitlinker/git.lua:446-447`
- **代码**：
  ```lua
  local splits = vim.split(result.stdout[1], "/", { plain = true, trimempty = true })
  return splits[#splits], nil
  ```
- **现象**：`refs/remotes/origin/HEAD` 指向 `refs/remotes/origin/release/v5` 时，`git rev-parse --abbrev-ref origin/HEAD` 输出 `origin/release/v5`，函数只返回最后一段 `v5`：
  ```
  实际生成: https://github.com/acme/demo/blob/v5/top.lua?plain=1#L1
  正确应为: https://github.com/acme/demo/blob/release/v5/top.lua?plain=1#L1
  ```
- **影响**：`:GitLink default_branch` 在 `release/x`、`feat/y`、`hotfix/z` 这类分支上生成 404 链接。默认的 `browse` 路由不受影响（它用 `_get_rev("@{u}")` 或 `HEAD`）。
- **复现**：
  ```bash
  git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/release/v5
  # 然后在仓库内的 buffer 里：
  :GitLink default_branch
  # → https://github.com/acme/demo/blob/v5/top.lua?plain=1#L1
  ```
- **相关（已实测）**：symbolic ref 指向不存在的分支时，`get_default_branch` 返回 `nil` + git 的 stderr（含 `fatal: ambiguous argument 'origin/HEAD'`）。`lua/gitlinker/linker.lua:156-159` 对这类错误只 `log.warn` 后继续，最终生成缺段的 url：
  ```
  :GitLink default_branch → https://github.com/acme/demo/blob//top.lua?plain=1#L1
  ```
  同时 `vim.notify` 会先吐出 5 行 git 的原始 stderr（`warning: ignoring dangling symref ...` 两条 + `fatal:` 三行），对用户不可读。
- **修复建议**：改成 `return (result.stdout[1]:gsub("^" .. vim.pesc(remote) .. "/", "")), nil`，让含 `/` 的分支名完整保留。

### 3. `_is_rev_in_remote` 用未转义的 Lua pattern 匹配分支名

- **位置**：`lua/gitlinker/git.lua:205`
- **代码**：
  ```lua
  for _, rbranch in ipairs(result.stdout) do
    if rbranch:match(remote) then
      return true, nil
    end
  end
  ```
- **现象**：remote 名被当成 Lua pattern，而且只做无锚点的子串匹配。
  - remote `ori` + 只有 `origin/main` 的仓库 → `rbranch = "origin/main"` 里含有子串 `ori`，`match` 命中，于是 `_is_rev_in_remote` 返回 `true`。
  - `git.get_closest_remote_compatible_rev("ori", dir)` 因此直接返回 HEAD 的 sha，`err = nil`。
  - 含元字符的 remote 名会误匹配：`o+` 匹配任何含 `o` 的分支行，`a.b` 匹配 `axb`，`a-b` 里的 `-` 在 Lua pattern 中是范围符号。
- **复现**：
  ```bash
  mkdir /tmp/patrepo && cd /tmp/patrepo && git init -q -b main
  git -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
  git remote add ori    https://example.com/ori.git
  git remote add origin https://example.com/origin.git
  git update-ref refs/remotes/origin/main HEAD   # 只有 origin/main，没有 ori/*
  # 在 neovim 里（fs 里跑 async.run）：
  git.get_closest_remote_compatible_rev("ori", vim.fn.getcwd())
  # → "c19184fc71b18fcba310d8570965e39738abb069"（= HEAD）, nil
  ```
- **影响**：远程兼容性检查误判为「该 rev 已在远程」，于是生成一个指向远程并不存在的 commit 的链接（404）。触发条件是「配置了 fetch refspec 且 HEAD 未推送」——恰是最需要这个检查正确的场景。
- **修复建议**：用 `vim.pesc(remote)` 转义并锚定成 `^<remote>/`；另外 `nil`（命令失败）与 `false`（真的不在远程）现在都走 falsy 分支，需要区分处理。

### 4. 不存在的 remote 名会让兼容性检查整体失效

- **位置**：`lua/gitlinker/git.lua:216-230`（`_has_remote_fetch_config`）、`lua/gitlinker/git.lua:278-290`（`is_usable`）
- **机制**：
  ```lua
  local remote_fetch_configured = _has_remote_fetch_config(remote, root) == true
  local function is_usable(revspec)
    if not remote_fetch_configured then
      return true                 -- ← 无法判断时一律放行
    end
    return _is_rev_in_remote(revspec, remote, root) == true
  end
  ```
  `git config remote.<name>.fetch` 在 key 不存在时退出码是 1，而 `_has_remote_fetch_config` 把 1 当作合法的「没有 fetch refspec」，返回 `false`。于是**任何不存在的 remote 名**都会让 `remote_fetch_configured` 变成 `false`，`is_usable()` 从此永远返回 `true`，兼容性检查被完全绕过。
- **实测**：在 `/tmp/patrepo` 里 `git.get_closest_remote_compatible_rev("zzz", cwd)` 返回 HEAD 的 sha（`c19184f…`），`err = nil`。
- **影响面**：比看上去小一些。`linker.make_linker` 在第 63 行就先调 `git.get_remote_url(selected_remote, root)`，未知名会得到 `error: No such remote 'zzz'`（exit 2），所以在正常链接路径上不会真的带着假 rev 往下走。真正受影响的是**直接调用 `git.get_closest_remote_compatible_rev` 的代码**（该函数在 `lua/gitlinker/git.lua:477` 被导出），以及未来若调整 `make_linker` 的调用顺序。
- **修复建议**：区分「remote 不存在」与「有 remote 但没配置 refspec」。前者用 `git remote` 列表先校验，或让 `_has_remote_fetch_config` 在 exit code 1 之后再确认 remote 存在；后者才走宽松分支。

### 5. 行号的取值域完全没校验（0、负数、超大值、浮点数）

- **位置**：`lua/gitlinker.lua:509-525`（`link()` 的归一化）、`lua/gitlinker.lua:244`（`_link` 的守卫）
- **现状**：`link()` 只检查 `type(x) == "number"`，且只保证 `lstart <= lend`；`_link` 同样只检查类型与顺序。没有任何「≥ 1」或「≤ buffer 行数」的约束，也没有整数性检查。
- **实测（fixture 仓库 `top.lua` 共 5 行）**：

  | 传入 | 生成锚点 | 说明 |
  |---|---|---|
  | `{lstart=0, lend=0}` | `#L0` | 行号 0 不存在 |
  | `{lstart=-3, lend=-1}` | `#L-3-L-1` | 负数原样输出 |
  | `{lstart=9999, lend=9999}` | `#L9999` | 超出 buffer 行数 |
  | `{lstart=1.5, lend=2.5}` | `#L1.5-L2.5` | 浮点数原样拼进 url |

- **附带**：浮点数在**开启高亮**时表现更糟——`_highlight_target`（`lua/gitlinker.lua:227` 的 `vim.fn.col({ opts.lend, "$" })`）抛 `Vim:E805: Using a Float as a Number`，该异常发生在 `_void_link` 的协程里，被 `async.run` 吞掉，结果是**既没有 url、也没有任何报错**（与第 6 条同源）。关掉高亮（`highlight_duration = 0`）时才能拿到 `#L1.5-L2.5` 这个错误锚点。
- **另一个静默点**：`_highlight_target` 自身的 `log.ensure(opts.lstart <= opts.lend, ...)`（`lua/gitlinker.lua:217-220`）也是抛错式断言，一旦触发同样会被协程吞掉——它现在由 `link()` 的归一化保证不会触发，属于「防御代码但错误不可见」。
- **影响**：API 调用方（`link({lstart = ...})`）传入脏数据时不会得到任何提示，只会生成一个 404 链接。命令行路径（`:GitLink`、`:1,4GitLink`）由 Vim 保证行号合法，不受影响。
- **修复建议**：在 `link()` 归一化之后加一次夹取：`lstart = math.max(1, math.floor(lstart))`、`lend = math.max(lstart, math.floor(lend))`，并可选地用 `nvim_buf_line_count(0)` 夹住上界；或者直接复用已存在但只有测试在用的 `range.is_range`（`lua/gitlinker/range.lua:52`）。

### 6. 协程内的错误被完全吞掉（action 回调抛错 / 高亮抛错）

- **位置**：`lua/gitlinker.lua:334-336`（`_void_link = function(opts) return async.run(_link, opts) end`，未加 `raise_on_error`）；抛错点 `lua/gitlinker.lua:283-285`（`opts.action(url)` 无保护）
- **现象**：`link({ action = function() error("BOOM-ACTION") end })`：
  ```
  同步 pcall 返回: ok=true, err=nil
  vim.notify 收到: 无（一条都没有）
  v:errmsg      : ""
  ```
  链接生成成功、日志里也有 info 记录，但用户的 action 抛的错彻底消失。
- **对比**：router 抛错是**会**被报告的（`lua/gitlinker.lua:269` `pcall(opts.router, lk, true)` + `lua/gitlinker.lua:276` `log.ensure`），所以问题只出在 `lua/gitlinker.lua:283-285` 的 `opts.action(url)` 以及其后的 `highlight.show` 调度上。
- **影响**：用户自定义 action（自定义剪贴板、`vim.ui.open` 封装、OSC52 之类）写错时，表现为「按了快捷键什么都没发生」，无法自查。
- **修复建议**：把 `opts.action(url)` 包进 `pcall` 并 `log.err`，或给 `_void_link` 加 `:raise_on_error`。仓库内的 `spec/testutil.lua` 已经因为同样的原因写了 `xpcall` + `debug.traceback` 的绕行，说明这是已知痛点。

### 7. `file=` 参数不检查文件是否存在

- **位置**：`lua/gitlinker/linker.lua:150-152`（显式 file 分支）；对照 `lua/gitlinker/linker.lua:135`（buffer 分支才会调 `git.is_file_in_rev`）
- **现象**：
  ```
  link({ file = "does/not/exist.lua" })
  → https://github.com/acme/demo/blob/<rev>/does/not/exist.lua?plain=1#L1
  ```
  不存在的路径照样生成链接，并且 `file_changed = false`（该分支不计算）。
- **另外**：`file` 也不做路径逃逸检查，`file = "../../etc/passwd"` 会原样进入 url。
- **影响**：`:GitLink file=...` 拼错文件名时得到 404 而非提示。
- **修复建议**：显式 file 分支也调用 `git.is_file_in_rev`，或者至少 `vim.uv.fs_stat` 一下再决定是否告警。

### 8. 切换 buffer 的竞态：链接的是「新」buffer 的文件，而非发起时的文件

- **位置**：`lua/gitlinker/linker.lua:115`（`async.await(1, vim.schedule)`）与 `lua/gitlinker/linker.lua:125`（`path.buffer_relpath(root)` 里读 `nvim_buf_get_name(0)`）
- **现象**：在 `multi.lua` 里触发 `link()`，紧接着 `:edit top.lua`：
  ```
  race url: .../top.lua?plain=1#L1     ← 发起时是 multi.lua
  ```
  切到仓库外的文件时则整条链路失败：`fatal: failed to resolve the buffer path relative to the git repository root: "/tmp/outside.lua" (root: "...")`，action 不执行。
- **原因**：`#341`（`91e0581 fix(highlight): resolve the highlight target before the first await`）只把**高亮目标**的 bufnr/行列提前解析了，**文件路径**仍然在第一个 `await` 之后才读 `nvim_buf_get_name(0)`。
- **影响**：正常交互几乎碰不到（人类切换 buffer 的速度慢于 1 个事件循环），但对「触发后立刻跳转」的自动化脚本/keymap 组合是真实竞态。
- **修复建议**：在进入 `make_linker` 之前就把 `bufnr` 与 `nvim_buf_get_name(bufnr)` 取好传下去，与高亮目标的处理方式保持一致。

### 9. `configs.setup()` 非幂等，且会改写 `router` 的表形状

- **位置**：`lua/gitlinker/configs.lua:361-366`
- **代码**：
  ```lua
  Configs = vim.tbl_deep_extend("force", vim.deepcopy(Defaults), opts or {})
  ```
- **问题 A（非幂等）**：
  ```lua
  configs.setup({ message = false, highlight_duration = 0 })
  configs.setup({})   -- 用户以为「再合并一次默认值」，实际是重置
  -- 结果: message = true, highlight_duration = 500
  ```
  每次 `setup` 都从 `Defaults` 重新开始，所以第二次调用会丢掉第一次调用的配置。README 第 315 行「Calling it a second time merges over the defaults again, so repeated calls are harmless」只在「两次传一样的参数」时成立。
- **问题 B（表形状）**：`vim.tbl_deep_extend("force", ...)` 对**列表**是整体替换。用户用 list 形式自定义 router 后：
  ```
  configs.setup({ router = { browse = { { "^git%.my%.host", "https://y/{_A.REV}" } } } })
  → get().router.browse            : string_keys=0, numeric_keys=1   ← 只剩用户那一条，默认 5 条不见
  → get()._routers.browse.map      : string_keys=5                   ← 默认值其实还在私有表里
  ```
  公开的 `router` 字段与真正生效的 `_routers` 形状/内容都不一致，按 README 读 `get().router` 会得到错误结论。
- **修复建议**：把已合并的 `_routers` 回写到 `Configs.router`（或干脆不暴露 `router`，改为文档化 `_routers`）；`setup` 改为在上一次 `Configs` 之上合并。

### 10. 命令行补全只给 router 类型，不看已输入的前缀

- **位置**：`lua/gitlinker.lua:472-482`
- **现象**：
  ```
  getcompletion("GitLink ", "cmdline")        → { blame, browse, current_branch, default_branch }
  getcompletion("GitLink remote=", "cmdline") → 同上
  getcompletion("GitLink file=", "cmdline")   → 同上
  getcompletion("GitLink rev=", "cmdline")    → 同上
  ```
  补全函数完全不看 `arglead`/`cmdline`/`cursorpos`，任何位置都返回同一份 router 列表。
- **影响**：`file=`/`rev=`/`remote=` 上按 Tab 会补出毫无意义的值，而真正需要的（remote 名、rev、路径）反而没有。
- **修复建议**：按 `arglead` 的前缀分派：`remote=` 补 `git remote` 结果，`file=` 补 `glob`，`rev=` 补 `git for-each-ref --format='%(refname:short)'`，否则才补 router 类型。

### 11. `get_branch_remote` 里有一段不可达代码

- **位置**：`lua/gitlinker/git.lua:400-428`
- **说明**：`lua/gitlinker/git.lua:392` 的 `if #remotes == 1 then return remotes[1], nil end` 提前返回，`lua/gitlinker/git.lua:396` 的 `if #remotes > 1` 走 `_select_remotes` 也返回了；能走到 `lua/gitlinker/git.lua:401` 的 `_get_rev_name("@{u}")` 时 `#remotes` 必然是 0。而 0 个 remote 时 `_get_rev_name("@{u}")` 直接失败并返回，所以：
  ```lua
  local upstream_branch_allowed_chars = "[_%-%w%.]+"
  local remote_from_upstream_branch = upstream_branch:match("^(" .. ... .. ")%/")
  ...
  string.format("fatal: parsed remote '%s' from remote branch '%s' is not a valid remote", ...)
  ```
  这一段（约 20 行，含两条错误消息）永远执行不到。
- **影响**：不是功能 bug，是维护负担——读者会误以为走 upstream 的解析路径被覆盖了，实际并没有。
- **修复建议**：删掉；若希望支持「多 remote 时优先用 upstream 所属 remote」，则应把它移到 `#remotes > 1` 分支里、`_select_remotes` 之前。

---

## 二、健壮性 / 性能风险

### 12. 建立一条链接要串行 spawn 12 个进程，其中 1 个是 `ssh`

- **实测（fixture 仓库，`vim.system` 计数）**：耗时 **50 ms**，12 次 spawn：
  ```
   1. git rev-parse --show-toplevel
   2. git remote
   3. git remote get-url origin
   4. ssh -ttG github.com            ← 纯开销
   5. git rev-parse @{u}
   6. git config remote.origin.fetch
   7. git branch --remotes --contains HEAD
   8. git rev-parse HEAD
   9. git cat-file -e <rev>:top.lua
  10. git diff <rev> -- top.lua
  11. git rev-parse --abbrev-ref origin/HEAD
  12. git rev-parse --abbrev-ref HEAD
  ```
- **`ssh -ttG`**（`lua/gitlinker/git.lua:235-262`，由 `lua/gitlinker/linker.lua:85` 调用）在**每一次**链接时都会跑一次，只为把 host 按 `~/.ssh/config` 的 `HostName` 别名改写成真实域名。实测单次约 **5.2 ms**，是 12 次 spawn 里最慢的一个（`git rev-parse` 约 1.5 ms、`git remote` 约 1.6 ms、`git cat-file` 约 2.2 ms，均为冷启动 `subprocess` 计时）。若机器上没有 `ssh` 会跳过；若 host 为空（本地路径 remote）会直接把 ssh 的 usage 文本当错误返回（见第 14 条）。
- **`git rev-parse --abbrev-ref origin/HEAD`** 与 **`git rev-parse --abbrev-ref HEAD`**（上面清单里的第 11、12 行）只为填 `default_branch`/`current_branch` 两个模板变量。默认模板里只有 `default_branch` 与 `current_branch` 两条路由（`lua/gitlinker/configs.lua:104/112/120/128` 与 `:146/154/162/170`）用得到它们，最常按的 `browse`/`blame` 完全不用。且这两处失败只 `log.warn`。
- **建议**：把这两个分支查询改成「按需」（模板里出现 `_A.DEFAULT_BRANCH`/`_A.CURRENT_BRANCH` 时才查）；`ssh -ttG` 的结果按 host 做进程内缓存（甚至写进 `stdpath("cache")`）。

### 13. 「找不到能用的 rev」时最多上百次串行 spawn

- **位置**：`lua/gitlinker/git.lua:301-309`
  ```lua
  for i = 1, 50 do
    local revspec = "HEAD~" .. i
    if is_usable(revspec) then              -- git branch --remotes --contains HEAD~i
      local rev = _get_rev(revspec, root)   -- git rev-parse HEAD~i
      ...
  ```
  每一轮 1–2 条 git 命令；50 轮之后还有一条兜底 `_get_rev(remote, root)`（`lua/gitlinker/git.lua:312`，即 `git rev-parse origin`）。
- **实测**：60 个 commit、无 upstream、`origin/main` 停在第一个 commit 的仓库（`/tmp/slowrepo`）里，`link()` **58 次 spawn、194 ms 后失败**。spawn 构成：
  ```
  1 x git rev-parse --show-toplevel
  1 x git remote
  1 x git remote get-url origin
  1 x ssh -ttG github.com
  1 x git rev-parse @{u}
  1 x git config remote.origin.fetch
  1 x git branch --remotes --contains HEAD
 50 x git branch --remotes --contains HEAD~N     ← 主循环
  1 x git rev-parse origin                        ← 兜底，也失败
  ```
  注意本轮 50 次 `is_usable()` 全部返回 false，所以 `git rev-parse HEAD~i` **一次都没跑**；如果 `is_usable` 返回 true，每轮还要再加一条，最坏可到 ~108 次 spawn。
- **额外问题**：兜底的 `git rev-parse origin` 只在 `refs/remotes/origin/HEAD` 存在时成功；否则整条链路以 `fatal: failed to get closest revision in that exists in remote: "origin"` 失败——这个句子的语法也是错的（`in that exists`，`lua/gitlinker/git.lua:319`）。
- **建议**：用一次 `git rev-list --remotes --max-count=50` 或 `git merge-base --is-ancestor` 批量判断，替代逐条 `--contains`；同时修正错误文案。

### 14. 本地路径 remote 实际不可用

- **位置**：`lua/gitlinker/git.lua:235-262`（`resolve_host`）、`lua/gitlinker/linker.lua:85`
- **现象**：`git remote add origin /tmp/localrepo` 后，
  ```
  giturlparser.parse("/tmp/localrepo") → host = nil, org = "tmp", repo = "localrepo"
  resolve_host(nil, root)              → nil, "usage: ssh [-46AaCfGgKkMNnqsTtVvXxYy] ..."
  ```
  于是链接失败，报的是 ssh 的 usage 文本——对用户完全不可读。
- **影响**：本地/裸仓库作为 remote（`file://`、绝对路径、`../other`）时插件不可用，而 README 对此既没说明支持、也没说明不支持。
- **建议**：`parsed_url.host == nil` 时直接给出明确错误（如 `fatal: local path remotes are not supported`），或在 README 里注明。

### 15. 多个 remote 时用阻塞式 `inputlist` 而不是 `vim.ui.select`

- **位置**：`lua/gitlinker/git.lua:358-380`（`vim.fn.inputlist` 在 `lua/gitlinker/git.lua:367`）
- **现象**：在 headless 环境下会直接挂住：
  ```
  1. origin (https://github.com/acme/demo.git)
  2. upstream (https://github.com/up/demo.git)
  Type number and <Enter> or click with the mouse (q or empty cancels):
  ```
  必须 SIGTERM 才能退出。
- **影响**：`inputlist` 是同步阻塞的，会卡住 Neovim 主循环（不能 `<C-c>` 取消前无法做任何事）。README 第 147 行把它称作 "picker"，容易让人以为是非阻塞 UI。headless/CI 里无法覆盖多 remote 场景。
- **建议**：改用 `vim.ui.select`（异步、可被用户替换为 telescope/fzf-lua 等），保留 `inputlist` 作为 fallback。

### 16. 高亮后无条件 `vim.cmd("redraw")`（低优先级）

- **位置**：`lua/gitlinker/highlight.lua:83`
- **说明**：`highlight.show()` 在 `vim.hl.range` 之后总是执行 `redraw`，即使没画任何东西（例如 range 完全在 buffer 之外，`vim.hl.range` 会静默忽略）。代码里 `-- Force the screen to highlight the text immediately` 表明这是有意的：`vim.hl.range` 加的是 extmark，不一定会立刻重绘。
- **实测**：`hl.show(0, {0,1}, {1,1}, 100)`、`{99,1}`、反向 `{3,1}->{1,1}`、`{1,99}` 都不抛错，只是静默无效果。
- **风险**：连按 keymap 时会多一次整屏重绘；在 `--headless` 下也无害。属于可优化项，不是缺陷。
- **建议**：若在意性能，可改为仅在 `timer ~= nil` 时 redraw；否则保持现状即可。

### 17. 文件日志无上限、无轮转

- **位置**：`lua/gitlinker/log.lua:6`（`LOG_FILE`）、`lua/gitlinker/log.lua:61`（`io.open(LOG_FILE, "a")`，每次调用都重新打开）
- **实测**：本机 `~/.local/share/nvim/gitlinker.log` 已达 **53,502,480 字节（约 51 MB）**，且没有任何截断/轮转逻辑。
- **附带**：每次写日志都 `io.open` + `close`，`log()` 里对每一行都重复一次（多行消息会开关多次）。
- **建议**：写之前检查大小，超过阈值（如 1 MB）时截断或 rename；或提供配置项。

### 18. 模板引擎对未知变量/字面大括号/含空格的表达式都只报底层错误

- **位置**：`lua/gitlinker.lua:13-93`（`_url_template_engine`）
- **实测**：

  | 模板片段 | 结果 |
  |---|---|
  | `{_A.NOPE}` | `invalid value (userdata) at index 2 in table for 'concat'` |
  | `{nil}` | 同上 |
  | `{{_A.ORG}}` | `Vim:E5107: Lua: [string "luaeval()"]:1: '}' expected near ')'` |
  | 未闭合 `{_A.FILE` | `failed to evaluate url template("...") at pos 12`（这条尚可读） |
  | `_A.ORG` 为空（`ssh://git@h/repo.git`） | 生成 `https://h//repo/...`（双斜杠） |

- **原因**：`vim.fn.luaeval` 把 `nil` 变成 `vim.NIL`（userdata），`table.concat` 遇到 userdata 直接抛；且没有 `{{`/`}}` 转义机制，url 里出现字面大括号就会解析失败。
- **影响**：用户自定义 router 写错变量名时，得到的错误与「模板」毫无关系。
- **建议**：对 `vim.NIL` 显式转成空串或报 `unknown template variable '<name>'`；支持 `{{`/`}}` 转义；对空 `_A.ORG` 做 `/` 折叠。

### 19. `map_routers` 用 `pairs` 迭代，优先级不确定

- **位置**：`lua/gitlinker.lua:155`、`lua/gitlinker.lua:167`
- **说明**：map 形式的 router 匹配顺序由 Lua 表的哈希顺序决定。实测重叠的 `^github` 与 `^github%.com` 在 20/20 次里都命中后者，但这是 LuaJIT 的实现巧合，不是保证。
- **影响**：默认 router 表里 `browse` 的 5 个模式互不重叠，所以默认配置安全；但用户添加了与默认值重叠的模式后，命中哪个不可预测。
- **建议**：文档明确「有序优先级请用 list 形式」；或在 `_merge_default_map_routers` 里把 map 转成有序数组。

---

## 三、测试与 CI 缺口

### 20. `selene` 在 CI 只扫 `./lua`，spec 里的 `after_each` 未被定义

- **位置**：`vim.toml`（只有 `[before_each] any = true`，**没有** `[after_each]`）；`.luarc.json` 的 `diagnostics.globals` 同样缺 `after_each`
- **实测**：`selene --config selene.toml .` 报 3 个错误：
  ```
  spec/gitlinker/root_spec.lua:79   error[undefined_variable]: `after_each` is not defined
  spec/gitlinker_spec.lua:789       error[undefined_variable]: `after_each` is not defined
  spec/gitlinker/highlight_spec.lua:216  error[undefined_variable]: `after_each` is not defined
  ```
  CI 里 `selene --config selene.toml ./lua` 扫不到 spec，所以长期没被发现。
- **建议**：`vim.toml` 补 `[after_each] any = true`，`.luarc.json` 的 globals 补 `after_each`。

### 21. `spec/gitlinker/git_spec.lua` 多个用例在「条件不满足时静默通过」

- 形如：
  ```lua
  local r, err = git.get_branch_remote(root)
  if r then assert_eq(type(r), "string") else assert_eq(type(err), "string") end
  ```
  在无 upstream 的仓库里走 else 分支，实际只断言了「错误是个字符串」。
- **影响**：`get_branch_remote`、`_get_rev("@{u}")`、`resolve_host` 这三条路径在 CI（`ubuntu-latest`、浅克隆、可能有也可能没有 `ssh`）上测到的内容和本地不同，覆盖率是浮动的。
- **建议**：用 `vim.system` 在临时目录里构造确定性的 remote/upstream 状态（`spec/gitlinker_spec.lua` 的 `[command range]` 块已经示范了这种写法），而不是依赖宿主仓库状态。

### 22. 没有 `giturlparser` 的测试

- `lua/gitlinker/giturlparser.lua`（563 行）是手写的 URL 解析器，被 `.styluaignore` 与 `selene.toml` 双重排除，`spec/` 下**没有**对应测试文件。
- 它承担了 `remote_url` → `protocol/host/port/org/repo` 的全部解析，是链接正确性的第一环。
- **建议**：至少覆盖 `https`/`ssh`/`scp-like`/`IPv6`/`file://`/本地路径 这几类输入。

### 23. 关键路径没有测试

- `_parse_args`（`lua/gitlinker.lua:349`）是 local，未导出，spec 里无法直接调用；引号/转义的处理目前只靠 `[command range]` 里的两个 e2e 用例覆盖。
- `link()` 的行号归一化（`lua/gitlinker.lua:509-525`）只测了 `{lend}`、`{lstart}`、`{5,3}`、`{2,2}`，**未覆盖** 0/负数/浮点/超界（即第 5 条）。
- `default_branch` 含 `/` 的分支名（第 2 条）、`file=` 指向不存在的文件（第 7 条）、action 抛错（第 6 条）都没有回归测试。

### 24. CI 覆盖面

- 所有 job 都是 `ubuntu-latest`，没有 windows/macOS（而 PR 模板里有 windows/macOS 的手工勾选项）。`lua/gitlinker/path.lua` 里的 `_normalize_sep` 专门处理 `\`，正是跨平台风险点。
- `nvim-typecheck-action` 依赖从 GitHub 下载 Neovim/LuaLS，实测会因 `504 Gateway Time-out` / 返回 HTML 错误页而失败（错误信息形如 `./nvim.appimage: line 1: syntax error near unexpected token '<'`），属于外部依赖不稳定，而非代码问题。
- 无 `doc/` 目录与 vim help 文件，`:help gitlinker` 不可用。

---

## 四、文档与代码不一致

### 25. README:315 的「重复调用 setup 无害」不成立

见第 9 条问题 A。原文：
> Calling it a second time merges over the defaults again, so repeated calls are harmless.

实际是每次从 `Defaults` 重建，第二次 `setup({})` 会清掉第一次的设置。

### 26. README:147 把阻塞式 `inputlist` 称为 "picker"

见第 15 条。真实行为是同步阻塞的 `vim.fn.inputlist`，不是可替换的 picker UI。

### 27. 零散的小文档问题

- `lua/gitlinker/git.lua:319` 的错误文案有语法错误：`failed to get closest revision in that exists in remote`。
- 本地路径 remote 的行为（第 14 条）在 README 中完全未提及。
- `README.md:145` 现在对 `file=` 的引号/转义描述是准确的（已随本次改动更新），但**未**说明它不做存在性检查（第 7 条）。

---

## 五、附：本次改动已修掉的问题（留档，避免重复排查）

- `link()` 会把默认值写回调用方传入的 opts 表 → 同一个表复用时会冻结第一次的行号（已由 `vim.deepcopy` 修复，PR #343）。
- `file=` 参数未经 `vim.uri_encode`（被 `_link` 里的 override 覆盖掉）→ 含空格路径生成非法 url（PR #343 已删掉 override）。
- `_parse_args` 不能处理引号与转义 → `file=some dir/a b.lua` 被拆成两段（PR #343 已加词法解析）。
- `link({lend = 6})`（只给一端）会让模板在 `luaeval` 里比较 `nil` 而抛 `E5108`（本分支 `ed7e9ff` 已改为自动补齐另一端）。
- 反向区间 `{lstart=5, lend=3}` 曾被模板静默丢弃右端（现在会排序成 `#L3-L5`）。
