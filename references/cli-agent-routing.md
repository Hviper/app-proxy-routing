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

To let ProxyBridge own routing, first remove proxy variables inherited by the target CLI without changing the global shell or system proxy. A wrapper can unset both upper- and lowercase `HTTP_PROXY`, `HTTPS_PROXY`, and `ALL_PROXY`, then `exec` the real binary. For OpenCode, also inspect its background service and any provider server started by Paseo: clearing the CLI environment alone does not clear an already-running server. Restart only idle affected agents/services and verify their process environments and ProxyBridge Connections. Preserve unrelated environment settings and other providers.

On macOS, ProxyBridge receives a TCP destination IP after the application resolves DNS. Its DNS proxy remembers a hostname for that IP temporarily; `sendDomain` sends the hostname only when that mapping is available. A process rule with `Target Hosts = *` does not guarantee remote DNS resolution. If Pi has a repeatable TLS hostname mismatch or wrong DNS answer while the ProxyBridge-only route is in use, diagnose the exact connection and DNS result before changing the route. A successful retry through the original Pi binary means the ProxyBridge-only path is viable at that moment, not that an earlier failure was explained.

For a confirmed Pi-specific DNS/TLS failure, a narrow fallback is an HTTPS application proxy through the dedicated Clash **mixed or HTTP** listener. Resolve its host and port at Pi launch from the active ProxyBridge process rule and proxy definition; do not copy a numeric port into the wrapper. Reject a missing/disabled rule or unavailable listener rather than falling back to direct or to the general `7890` port. Clear inherited proxy variables, then set only Pi's needed `HTTPS_PROXY` and an appropriate `NO_PROXY` for loopback and known internal destinations. Validate the listener supports HTTP CONNECT. This HTTPS request goes from Pi straight to the Clash listener; it does not traverse ProxyBridge's per-process relay, even though ProxyBridge remains the configuration source for the endpoint. Keep other CLI agents on ProxyBridge-only routing unless their own failure requires an exception.

After changing a listener, ProxyBridge rule/profile, or wrapper, restart affected idle CLI agents so new processes read the current configuration. Existing long-lived connections keep their previous route. Verify a representative request and the relevant ProxyBridge/Clash connection record. Child tools have their own process identities; inspect Connections and add narrow child-process rules only when the user wants those flows routed.

See ProxyBridge's [macOS routing and DNS design](https://proxybridge.interceptsuite.com/docs/macos-how-it-works/) and [troubleshooting guide](https://proxybridge.interceptsuite.com/docs/macos-troubleshooting/) for the DNS-map and process-match limits.

## Verification without an account request

Use the least invasive check that answers the user's question:

1. **Dedicated-listener probe:** make a small unauthenticated HTTPS request through the Clash listener to a hostname observed in the agent's logs. This tests DNS/TCP/TLS/HTTP reachability for that route, not ProxyBridge's process matching and not account/model availability.
2. **Process-aware probe:** when needed, cause the actual CLI process to make one unauthenticated request to the observed hostname, with inherited proxy variables cleared. For Pi, this can be a temporary in-process extension or another documented no-model-request mode. Confirm the process name and endpoint in ProxyBridge Connections. Confirm Clash's selected group/node in its own connection view when available.
3. **Authenticated app test:** send a model request only when the user requested that assurance and it is appropriate for the signed-in account. Test sequentially and avoid rapid exit-IP changes.

Report exact HTTP status. A response such as 404 can establish that the host answered over the route, but it is not proof that an authenticated model endpoint or account is usable. Never include cookies, tokens, or prompt contents in an unauthenticated probe. A Clash listener connection name in ProxyBridge confirms the configured handoff target; use Clash's connection view to confirm the selected group/node when that evidence is available.
