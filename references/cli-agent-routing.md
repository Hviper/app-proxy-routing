# CLI agent routing on macOS

Use this guide when routing Antigravity's `agy` CLI, Pi, or Codex CLI through ProxyBridge to a dedicated Clash Verge Rev group. Keep desktop apps, CLI processes, language servers, and spawned tools distinct until ProxyBridge Connections shows which identities actually open relevant connections.

## Identify the network process

1. Start the exact entry point the user uses: terminal, Paseo, editor, or desktop app. Capture ProxyBridge Connections during startup and a representative request.
2. Record the process name, bundle ID when present, host, protocol, rule result, and endpoint for each relevant connection. Do not infer coverage from the number of rules or from a process-list snapshot.
3. Add a process rule for each required network origin. A process-specific `Target Hosts = *` covers any destination for that identity, but not separately named helpers or child processes. Avoid rules for generic `node`, `python`, `bash`, or `language_server` unless their origin is verified and the broader match is intended.

Common distinctions to check:

- **Antigravity:** the desktop app and the `agy` CLI are different launch paths. The language server may open its own connections; add a rule for it only when Connections shows that it needs the route.
- **Codex:** the `codex` CLI, Codex desktop app, service/helper, and shell tools are distinct identities. A rule named `codex` does not automatically cover the desktop app or children.
- **Pi:** an npm-installed `pi` command may be a JavaScript shim with `#!/usr/bin/env node`. ProxyBridge can then identify the network origin as `node`, which is too broad to match safely on most developer machines. Do not enable a machine-wide `node` rule just to route Pi.

## Pi standalone binary

When the user needs Pi's CLI to match independently across terminal and GUI launchers, use an official standalone release for the machine architecture if available. Pi publishes versioned macOS archives such as `pi-darwin-arm64.tar.gz` and `pi-darwin-x64.tar.gz` on its [official releases page](https://github.com/earendil-works/pi/releases).

1. Check the current `pi` command, architecture, and version before replacement. Download the matching release archive and its `SHA256SUMS` from the same official release, then verify the archive before extracting it.
2. Install the complete extracted directory, including its runtime assets. Do not compile only the npm package's JavaScript bundle and treat that as a complete standalone installation; package metadata, workers, and assets can be missing.
3. Preserve the existing launcher as a reversible backup unless the user explicitly asks to remove it. Point every relevant command path (for example, `~/.local/bin/pi` and `/opt/homebrew/bin/pi`) to the standalone install or to a launcher that execs it.
4. Verify `pi --version`, inspect the installed executable with `file`, and check the actual runtime process in ProxyBridge Connections. A successful `--version` check alone does not prove network routing.
5. Avoid assuming a global npm update will preserve the standalone entry point. Follow the update method for the installation actually in use.

## Proxy environment variables and wrappers

CLI clients may honor `HTTP_PROXY`, `HTTPS_PROXY`, `ALL_PROXY` and their lowercase forms. If those point to a local mixed port such as `7890`, the client may connect to loopback first; an early loopback DIRECT rule then bypasses the app-specific ProxyBridge rule. Paseo or an editor may also inject its own per-agent proxy variables.

If the user wants ProxyBridge to own routing for one CLI, clear proxy variables only for that command, rather than changing the shell or system-wide proxy. For a standalone Pi binary, a small launcher can do this and then replace itself with Pi:

```sh
#!/bin/sh
unset HTTP_PROXY HTTPS_PROXY ALL_PROXY http_proxy https_proxy all_proxy NO_PROXY no_proxy
exec /absolute/path/to/standalone/pi "$@"
```

Point the user's actual PATH locations and GUI launcher to this wrapper, then verify the final network process is still identified as `pi`. If the CLI inherits a provider-level proxy setting, either use a command wrapper that clears it or remove only that provider's override when the user wants ProxyBridge to be the routing layer. Preserve other agent providers' settings.

Clearing proxy variables affects children spawned by the CLI too. Their traffic is not covered by the parent CLI's process rule; inspect Connections and add narrow child-process rules only when the user wants those flows routed. Do not claim that every shell command, updater, extension, or helper is covered by the main agent rule.

## Verification without an account request

Use the least invasive check that answers the user's question:

1. **Dedicated-listener probe:** make a small unauthenticated HTTPS request through the Clash listener to a hostname observed in the agent's logs. This tests DNS/TCP/TLS/HTTP reachability for that route, not ProxyBridge's process matching and not account/model availability.
2. **Process-aware probe:** when needed, cause the actual CLI process to make one unauthenticated request to the observed hostname, with inherited proxy variables cleared. For Pi, this can be a temporary in-process extension or another documented no-model-request mode. Confirm the process name and endpoint in ProxyBridge Connections. Confirm Clash's selected group/node in its own connection view when available.
3. **Authenticated app test:** send a model request only when the user requested that assurance and it is appropriate for the signed-in account. Test sequentially and avoid rapid exit-IP changes.

Report exact HTTP status. A response such as 404 can establish that the host answered over the route, but it is not proof that an authenticated model endpoint or account is usable. Never include cookies, tokens, or prompt contents in an unauthenticated probe. A Clash listener connection name in ProxyBridge confirms the configured handoff target; use Clash's connection view to confirm the selected group/node when that evidence is available.
