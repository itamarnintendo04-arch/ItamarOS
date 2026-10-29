# ItamarCODE — separate optional desktop code editor

**ItamarCODE is not an ItamarOS built-in app.** It has its own source project, app name, icon, package build and installation process. It is based on the open-source **Eclipse Theia** IDE framework, a modular desktop development environment using Monaco (the editor engine also used by VS Code). <https://theia-ide.org/docs/composing_applications/>

## Planned VS Code-like features configured in the source

The Electron desktop project lists Theia extensions for:
- Monaco syntax-highlighted multi-tab editor, minimap and modern language-aware editing support when language servers/plugins are installed.
- Project workspace/file explorer, file search and search-in-workspace, outline, breadcrumbs, symbol/type/call hierarchy.
- Integrated terminal and execution of tasks.
- Git source control (Theia Git + SCM), changes, diff and history provided by installed extensions.
- Debug UI, breakpoints, debugger integrations when language-specific debug adapters are installed.
- Keyboard shortcuts, themes/preferences, problems/markers/output, editor preview and notebook support.
- Compatibility with **many**, but not all, VS Code extensions via `@theia/plugin-ext-vscode`, and discovery through Open VSX (`@theia/vsx-registry`).

**Important:** This is **not** the proprietary Microsoft Visual Studio Code distribution. We cannot truthfully promise every Microsoft-only VS Code feature or every third-party extension: the official Marketplace and some remote development and proprietary extensions have separate usage restrictions and compatibility limitations. No Microsoft trademarks, VS Code logos or Marketplace credentials are embedded in this project. VS Code Code-OSS and Microsoft's product differ in proprietary features. Refer to https://code.visualstudio.com/docs/supporting/faq.

## Build from source (development, unverified)

On a Windows, Linux or Mac developer machine with compatible Node.js, Yarn classic, native build tools and Theia's prerequisites:

1. Open the `itamarcode` directory; run `yarn install`.
2. Run `yarn rebuild` and `yarn build`.
3. Start the development IDE with `yarn start`.

Theia native dependencies may need platform-specific build toolchains. The package has **not yet passed a full Electron build**, is **not a signed installable application**, and should not be downloaded as an EXE from the main ItamarOS releases. This is a separate optional application scaffold for development.

## Platform scope

Desktop: intended for Windows, macOS and Linux (independent of the ItamarOS operating system). Full local terminal/workspace/debug features require local desktop access. iPhone/iPad/Apple TV/Android TV cannot run arbitrary local desktop IDE processes in the same manner, and there is currently no ItamarCODE native mobile or TV release. Use dedicated platform UIs or a user-approved remote development service in the future.

## Security and license

Uses Theia's open-source licensed extension packages and Electron. Dependency installs and running source builds execute code: use trusted reviewed dependencies and a non-privileged developer account; no arbitrary extensions/plugins auto-installed. The ItamarOS Store must not bundle or auto-install this app without opt-in. VS Code itself, Code-OSS, and Eclipse Theia have distinct terms.

## Roadmap

- Verify a real cross-platform Electron build on CI.
- Add ItamarCODE native package icon and build release metadata.
- Add project templates, keyboard shortcuts reference, optional GitHub integration and opt-in extensions.
- Independently test desktop debug adapters, LSPs, terminal and plugin compatibility.
