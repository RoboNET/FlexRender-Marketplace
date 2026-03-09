# FlexRender Plugin for Claude Code

Skills and tools for working with [FlexRender](https://github.com/RoboNET/FlexRender) — a modular .NET library for rendering images from YAML templates with flexbox layout.

## Installation

```bash
# 1. Add the marketplace (one-time)
claude plugin marketplace add https://github.com/RoboNET/FlexRender-Marketplace

# 2. Install the plugin
claude plugin install flexrender@FlexRender-Marketplace
```

## Skills

### `template`
Full-cycle YAML template authoring: create, edit, debug, render, and watch templates. Includes complete syntax reference for all 11 element types, flexbox layout, template expressions, and CLI commands.

### `template-csharp`
C# integration: build templates programmatically with the AST API, configure `FlexRenderBuilder`, integrate via DI, select NuGet packages per scenario. Includes AOT-safe coding patterns and ready-to-use snippets.

### `content-formats`
Reference for content parsers: Markdown, HTML, and NDC (ATM receipt) formats. Covers element mapping, parser options, and usage in both YAML and C#.

## CLI Auto-Management

The plugin automatically checks for the `flexrender` CLI on session start:
- If not installed: installs via `dotnet tool` or downloads native binary
- If outdated: warns and suggests upgrade
- If current: runs silently

## Requirements

- Claude Code
- One of: .NET SDK (for `dotnet tool install`) or `curl`/`wget` (for binary download)

## Versioning

Plugin `major.minor` tracks FlexRender releases. `patch` is plugin-specific.
