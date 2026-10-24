# App Proxy Routing

A Codex Agent Skill and runbook for routing one macOS application's traffic through a dedicated Clash Verge Rev proxy group with ProxyBridge, while leaving unrelated applications and explicitly listed LAN services direct.

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

The dedicated inbound bypasses normal Clash rule matching for connections arriving on that listener. It does not alter the ordinary mixed port, system-wide proxy, or TUN mode. Per-app interception depends on matching the actual processes that originate traffic; helper processes and app-owned network extensions may need separate diagnosis.

## Safety and limitations

- The sample configuration is illustrative; validate port availability, active profile schema, and proxy names before applying.
- A node health check or public IP lookup does not prove the target service accepts its exit. Verify with a minimal request to the actual service and use only locations permitted for the user's account.
- macOS ProxyBridge uses a Network Extension and needs user approval to activate. Its UDP rules match the app but do not filter UDP by destination host or port.
- Keep the listener bound to loopback. Do not enable TUN or alter system-wide proxy settings unless the user explicitly requests it.

See the runbook for the detailed workflow and primary documentation links.
