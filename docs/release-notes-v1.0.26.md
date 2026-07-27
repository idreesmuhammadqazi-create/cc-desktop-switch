# CC Desktop Switch v1.0.26

## English

This patch release enables the Chat tab when applying the Claude Desktop third-party (3P) configuration.

- Added `chatTabEnabled` to the Claude Desktop policy writes so the Chat tab appears alongside Cowork and Code after applying the local gateway config. Chat is opt-in per Anthropic's 3P config reference and defaults to off; this app now opts the configured install in.
- The new key is written to the Windows registry (regular + elevated PowerShell paths), the macOS plist, the root macOS JSON config, and the active `configLibrary` entry. `chatTabEnabled` is included in the managed-key set so "Clear Desktop config" also removes it.
- Updated test fixtures to cover the new key round-trip.

No user configuration migration is required. After upgrading, re-apply the active provider and fully restart Claude Desktop for the Chat tab to appear.

## 简体中文

本次小版本在一键应用 Claude Desktop 第三方（3P）配置时启用 Chat tab。

- 在 Claude Desktop policy 写入里新增 `chatTabEnabled`，一键应用后 Chat tab 会和 Cowork、Code 一起显示。Chat 在 Anthropic 3P 配置参考里是 opt-in、默认关闭的，本工具现在会自动开启已配置实例的 Chat。
- 新 key 同时写入 Windows 注册表（常规 + 提权 PowerShell 路径）、macOS plist、macOS 根 JSON 配置以及当前生效的 `configLibrary` 条目。`chatTabEnabled` 也被加入 managed-key 集合，“清除 Desktop 配置”会一并清理。
- 同步更新测试用例，覆盖新 key 的读写回环。

不需要迁移用户配置。升级后重新对当前 provider 执行“一键应用到 Claude 桌面版”，然后完整重启 Claude Desktop 即可看到 Chat tab。