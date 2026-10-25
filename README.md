# open-claude-usage-tray

A tiny macOS menu bar app that shows your Claude plan limits — current session and weekly — with traffic-light bars, the same numbers you see on [claude.ai/settings/usage](https://claude.ai/settings/usage).

- Menu bar: `3% · 2%` (session · weekly), orange/red when you're getting close.
- Popover: one bar per limit, colored green → orange → red, with a live "Resets in" countdown.
- Notifications when a limit moves up to warning or critical.

No settings, no dependencies, ~300 lines of Swift.

## Requirements

- macOS 13+
- [Claude Code](https://claude.com/claude-code) installed and logged in. The app reuses its login from the Keychain; you don't enter any credentials.

## Build & run

Only the Xcode Command Line Tools are needed (`xcode-select --install`):

```bash
./bundle.sh
open build/OpenClaudeUsageTray.app
```

To start it at login: System Settings → General → Login Items → add `OpenClaudeUsageTray.app`.

Tests need full Xcode: `swift test`.

## How it works

1. Reads Claude Code's OAuth token with `/usr/bin/security find-generic-password -s "Claude Code-credentials" -w`. Claude Code writes that Keychain item with the same tool, so reading it never prompts for a password.
2. Calls `GET https://api.anthropic.com/api/oauth/usage` every 5 minutes; after a rate limit it waits for the server's `Retry-After`.
3. Draws each entry of the response's `limits` array, using its `severity` for the color.

The token is re-read on every poll, so it stays valid as long as Claude Code keeps refreshing it. If it expires (e.g. after days without using Claude Code), run `claude` and `/login` again.

> The usage endpoint is undocumented and may change or disappear at any time.

## Disclaimer

Not affiliated with or endorsed by Anthropic. "Claude" is a trademark of Anthropic.

## License

[MIT](LICENSE)
