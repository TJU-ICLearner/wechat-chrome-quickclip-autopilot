---
name: wechat-chrome-quickclip-autopilot
description: Clip a user-provided WeChat Official Account link through the normal Chrome profile and Obsidian Web Clipper, then organize the confirmed raw note into the SOC Learning LLM Wiki. Works in this Codex chat or through cc-connect.
---

# 微信公众号 Chrome Quick clip 自动归档

Use this skill for a single `https://mp.weixin.qq.com/...` link provided directly
in this Codex chat or received through cc-connect. It is specific to the user's
existing Chrome profile and Obsidian Web Clipper configuration. Read the active
vault's `AGENTS.md` and `CLAUDE.md` for its storage and organization schema.

## Required route

1. Read the vault's `AGENTS.md`, `CLAUDE.md`, and the detailed operational
   guide at [references/运行说明.md](references/运行说明.md).
2. Do not retrieve the WeChat page through HTTP, Defuddle, a browser-control
   tool, CDP, or a separate Chrome profile. Run exactly:

   ```zsh
   "${CODEX_HOME:-$HOME/.codex}/skills/wechat-chrome-quickclip-autopilot/scripts/clip-wechat-in-chrome.zsh" '<URL>'
   ```

   The script uses a local boolean readiness check on the already-open tab; it
   neither returns nor stores article text. It then foregrounds the user's
   normal Chrome only long enough to trigger the already-configured Obsidian
   Web Clipper Quick clip keyboard command (`⌥⇧O`).
3. Interpret the command's JSON result:
   - `captured`: read only the returned raw Markdown file. Verify meaningful
     article content and the original `mp.weixin.qq.com` URL.
   - `busy`: report that another clipping task is still active; do not retry.
   - `permission_required`: request the one-time macOS Accessibility permission
     for `/usr/bin/osascript`; do not attempt a workaround.
   - `chrome_unavailable`: ask the user to open their normal Chrome Profile
     containing Obsidian Web Clipper and make that window frontmost; never
     select, create, or infer a different Chrome Profile.
   - `pending`: report the stated local condition. If it requests Chrome's
     “Allow JavaScript from Apple Events” setting, ask the user to enable that
     one-time Chrome developer setting; otherwise check Web Clipper's target
     folder and the Chrome loading/login state.
   - `error`: report the exact local validation failure without fetching a
     substitute source.
4. Only after `captured`, organize that exact raw file using
   `$wechat-obsidian-autopilot`. Follow the vault schema, preserve raw article
   wording, update the required wiki pages, and verify links.
5. Send one concise completion message only after the raw note and wiki updates
   are both confirmed. In this Codex chat, report normally; through cc-connect,
   avoid progress chatter and send only the final message.

## Boundaries

- Never inspect or export Chrome cookies, passwords, profile data, or login
  state. Do not change Chrome, Web Clipper, Obsidian, or cc-connect settings.
- If WeChat presents a CAPTCHA, verification page, login wall, or incomplete
  article, stop and ask the user to resolve it in their normal Chrome. Do not
  bypass it.
- The legacy directory-watcher launch agent is intentionally disabled because
  macOS background privacy controls cannot reliably read this vault in
  `Documents`. The originating cc-connect task owns capture and organization.

For setup, status meanings, troubleshooting, and maintenance, read
[references/运行说明.md](references/运行说明.md).
