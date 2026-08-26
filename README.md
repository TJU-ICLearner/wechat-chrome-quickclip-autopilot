# WeChat Chrome Quick Clip Autopilot

一个可安装到 Codex 的 Skill：将用户提供的微信公众号文章链接，通过**日常 Chrome Profile** 与已配置的 **Obsidian Web Clipper Quick clip** 保存到 Obsidian，然后在确认原文已落盘后交给 Codex 整理。

它不抓取微信公众号 HTTP 页面、不读取 Cookie/密码/浏览器 Profile，也不会绕过登录、验证码或 CAPTCHA。

## 它解决什么问题

微信公众号对直接抓取和无头浏览器常有限制，而用户已有的日常 Chrome 登录态和 Obsidian Web Clipper 是更可靠的资料入口。本 Skill 用 macOS Automation 调用那条已有链路：

```text
用户粘贴 mp.weixin.qq.com 链接
        ↓
Skill 校验链接并锁定单次任务
        ↓
日常 Chrome 前台打开文章
        ↓  等待页面渲染
发送 Obsidian Web Clipper Quick clip 快捷键（默认 ⌥⇧O）
        ↓
Obsidian Web Clipper 写入 <vault>/raw/articles/
        ↓
脚本按原始 URL 轮询确认 Markdown 已真实出现
        ↓
Codex 根据 vault 规则生成来源摘要、概念链接、索引与日志
```

“已打开链接”不等于完成：只有找到包含原始 URL 的新 Markdown 时，脚本才返回 `captured`，随后才允许知识库整理。

## 目录结构

```text
wechat-chrome-quickclip-autopilot/
├── SKILL.md                         # Codex 的工作流指令
├── README.md                        # 本文
├── agents/openai.yaml               # Codex UI 元数据
├── scripts/clip-wechat-in-chrome.zsh # 确定性的本地剪藏脚本
└── references/运行说明.md            # 运行、故障排查与维护细节
```

## 前置条件

- macOS，安装 `zsh`、`osascript`（系统自带）、`rg` 和 `jq`。
- Google Chrome 正常安装；使用的是你日常的、包含文章登录态的 Profile。
- 已安装 [Obsidian Web Clipper](https://obsidian.md/clipper) 扩展，并且 **Quick clip** 配置为无需确认直接写入目标 vault 的 `raw/articles`。
- Web Clipper 快捷键为 `⌥⇧O`；如有改动，请对应调整脚本。
- macOS「系统设置 → 隐私与安全性 → 辅助功能」已允许 `/usr/bin/osascript` 发送按键。
- 需要一个 Obsidian vault；若希望自动生成知识库层，还应有 `AGENTS.md` / `CLAUDE.md` 说明 `raw/` 与 `wiki/` 的维护规则。

## 安装

将目录放入 Codex 的 Skill 目录：

```zsh
git clone https://github.com/TJU-ICLearner/wechat-chrome-quickclip-autopilot.git \
  "${CODEX_HOME:-$HOME/.codex}/skills/wechat-chrome-quickclip-autopilot"
```

然后重启或刷新 Codex 的 Skill 列表。也可以把此仓库作为本地 Skill 目录安装；关键是其中必须保留 `SKILL.md`。

## 配置

脚本默认 vault 为 `~/Documents/SOC Learning`。通过环境变量适配任意 vault：

```zsh
export OBSIDIAN_VAULT_DIR="$HOME/Documents/My Vault"
# 可选：不在默认 raw/articles 时设置
export OBSIDIAN_RAW_DIR="$OBSIDIAN_VAULT_DIR/raw/articles"
# 可选：渲染慢的页面可提高等待时间；默认 12 秒
export WECHAT_CLIP_WAIT_SECONDS=15
# 可选：每 2 秒检查一次，默认 30 次（约 60 秒）
export WECHAT_CLIP_POLL_ATTEMPTS=30
```

环境变量应配置在运行 Codex/Claudian/cc-connect 的同一进程环境中。Quick clip 的 Obsidian 目标文件夹必须与 `OBSIDIAN_RAW_DIR` 一致。

## 使用

在 Codex 或使用 Codex provider 的 Claudian 中显式调用：

```text
$wechat-chrome-quickclip-autopilot https://mp.weixin.qq.com/s/...
```

也可让 Skill 自动匹配单一 `mp.weixin.qq.com` 链接。调用过程中 Chrome 会短暂前置；不要在等待与快捷键发送之间切换到其他应用或标签页。

### 推荐入口：直接调用 Codex / Claudian

日常使用优先直接在 Codex 对话中粘贴链接，或在 Obsidian 的 Claudian 中选择 **Codex provider** 后调用本 Skill。这条路径没有 cc-connect 的微信回信额度，完成结果可以正常返回到当前任务。

### 可选入口：cc-connect / 微信

cc-connect 可以把手机微信里的 `/new + 公众号链接` 转为 Codex 任务，适合不在电脑旁时收集文章；它不是运行本 Skill 的必需组件。完成剪藏和整理的机器仍需处于可操作状态，并具有本 README 中的 Chrome、Web Clipper 与辅助功能授权。

需要注意 cc-connect 的发送保护：它会在本地配置中以一个**滚动 24 小时窗口**限制向微信发送消息的次数（例如 `burst_window_secs=86400`，实际额度由项目配置决定），而微信/iLink 服务端还可能施加额外频率限制。因此，任务即使已经执行完毕，最终回信仍可能因 24 小时额度耗尽而无法送达；提高本地限额并不会提高服务端额度，反而更容易触发服务端限流。

建议策略：

- 用微信/cc-connect 只做低频、异地的文章投递；一次任务只回传最终结果，避免进度消息消耗额度。
- 高密度收集、调试与确认处理结果时，直接使用 Codex 或 Claudian 的 Codex provider。
- 若经 cc-connect 投递后没有收到回信，以 `<vault>/raw/articles/`、`wiki/sources/`、`wiki/index.md` 与 `wiki/log.md` 是否出现对应条目作为完成依据。

单独测试剪藏脚本：

```zsh
"${CODEX_HOME:-$HOME/.codex}/skills/wechat-chrome-quickclip-autopilot/scripts/clip-wechat-in-chrome.zsh" \
  'https://mp.weixin.qq.com/s/…'
```

## 返回状态

| 状态 | 含义 | 应对方式 |
| --- | --- | --- |
| `captured` | 已找到包含原始 URL 的新 Markdown。 | 可以开始整理知识库。 |
| `busy` | 另一篇文章仍在剪藏。 | 等待结束，不要并发发送快捷键。 |
| `permission_required` | macOS 拒绝键盘自动化。 | 授权 `osascript` 辅助功能后重试。 |
| `chrome_unavailable` | AppleScript 无法操作 Chrome。 | 打开带 Web Clipper 的日常 Chrome 窗口并置前。 |
| `pending` | 快捷键已发送，但没有确认新文件。 | 检查 Web Clipper 的 Quick clip vault、文件夹和模板。 |
| `error` | URL 或配置参数不合法。 | 修正输入或环境变量。 |

## 安全边界

- 不读取、导出或上传 Cookie、密码、Profile、登录凭据或文章以外的浏览器数据。
- 不使用 HTTP、CDP、Defuddle、无头浏览器或专用 Chrome Profile 抓取公众号内容。
- 遇到验证码、登录墙、付费墙或正文不完整时停止；由用户在 Chrome 中完成验证。
- 原始文章是事实来源；后续整理应写入 wiki 层，而不要改写正文。
- 日志仅保存在 `<vault>/.claudian/logs/`，并且不应包含令牌或账号标识。

## 已知限制

- 这是 macOS + Chrome + Obsidian Web Clipper 的组合方案，不支持 Linux/Windows。
- 自动化依赖焦点窗口和快捷键；Chrome 被其他应用抢焦点时可能导致 `pending`。
- 只串行处理一个链接，以避免快捷键误发到错误文章。
- 文章图片能否本地化取决于 Web Clipper 配置；本 Skill 只确认 Markdown 已落盘。

更多部署和维护细节见 [references/运行说明.md](references/运行说明.md)。
