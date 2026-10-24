# App Proxy Routing

A Codex Agent Skill and runbook for routing one macOS application's traffic through a dedicated Clash Verge Rev proxy group with ProxyBridge, while preserving unrelated applications' pre-existing routes and adding direct exceptions for identified LAN services.

## Included

- `SKILL.md` — when and how agents should apply the skill.
- `references/proxy-runbook.md` — setup model, candidate validation, ProxyBridge rule order, acceptance checks, and rollback.

## Install for Codex

Copy this directory to `~/.codex/skills/app-proxy-routing`. The Skill is also usable by other agents that support the standard `SKILL.md` format and relative reference files.

## Route model

```text
selected app/helper -> ProxyBridge rule -> 127.0.0.1:<dedicated port>
                    -> Mihomo listener with proxy: <dedicated selector group>
                    -> selected upstream node
```

The dedicated inbound bypasses normal Clash rule matching for connections arriving on that listener. Reuse a valid existing dedicated group/listener; create only missing or invalid pieces. It does not alter the ordinary mixed port, system-wide proxy, or TUN mode. Keep Clash Verge/Mihomo and ProxyBridge running while using the target app; the system proxy may remain off. ProxyBridge unmatched traffic returns to macOS; if the system proxy is enabled, an app that honors it may still use Clash's ordinary rules. A `Target Hosts = *` rule covers any destination for the matched app/process, not other processes. Helper processes and app-owned network extensions may need separate diagnosis. Saved ProxyBridge rules apply to new connections immediately; restart the target app/helper only if existing long-lived connections need to reconnect. ProxyBridge normally does not need restarting after rule edits.

Use profile-scoped Merge/Script by default. Global extensions are supported when the user asks for cross-profile behavior, but must be dynamically validated against every profile; never promote a profile-specific script without checking that all referenced nodes and groups exist.

For subscriptions that rename nodes, selector membership should be generated from the active profile's current proxy entries in a Script. Static node-name lists in Merge YAML can become stale after a subscription refresh; dynamic membership still requires rechecking the selected node and target-service access.

To refresh nodes after a subscription update, invoke the Skill. It supports unauthenticated domain probes for bulk network screening and authenticated target-app requests for end-to-end verification. These produce different result labels; a reachable domain is not proof the software/account accepts the node. The Skill does not run in the background; unattended checks require a separate watcher/automation and a bounded request budget.

## Safety and limitations

- The sample configuration is illustrative; validate port availability, active profile schema, and proxy names before applying.
- A node health check or public IP lookup does not prove the target service accepts its exit. Verify with a minimal request to the actual service and use only locations permitted for the user's account.
- macOS ProxyBridge uses a Network Extension and needs user approval to activate. Its UDP rules match the app but do not filter UDP by destination host or port.
- Keep the listener bound to loopback. Do not enable TUN or alter system-wide proxy settings unless the user explicitly requests it.

See the runbook for the detailed workflow and primary documentation links.
