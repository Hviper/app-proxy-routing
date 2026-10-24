---
name: app-proxy-routing
description: Configure and verify per-application proxy routing on macOS with Clash Verge Rev and ProxyBridge, including a dedicated Clash listener and app-specific rules. Use when a user asks to route one app or agent through a chosen Clash proxy group while keeping other apps or LAN traffic direct.
metadata:
  short-description: macOS per-app proxy routing
---

# App Proxy Routing (macOS)

Use this skill when a user wants one application—such as Antigravity (`agy`)—to use a verified Clash Verge Rev proxy group without changing the route used by unrelated applications.

Read [the operator runbook](references/proxy-runbook.md) before changing a live proxy profile or ProxyBridge rules. It contains the configuration model, safe setup, test criteria, and rollback procedure.

## Required outcome

Build and verify this path:

```text
target app and its network helpers
  -> ProxyBridge app/process rule
  -> local SOCKS5 or HTTP endpoint on Clash Verge Rev
  -> dedicated mixed inbound bound to 127.0.0.1:<unused-port>
  -> dedicated Clash selector group
  -> selected upstream node
```

The dedicated inbound's `proxy: <group-name>` sends those connections straight to that group. It does not pass through the normal `7890` mixed-port rule matching. The group still selects or forwards to its configured member; a listener does not make an unavailable node usable.

## Workflow

1. Identify the target app, service/account to test, app bundle ID, and any helper processes that make network requests. Inspect the current Clash Verge Rev profile, mode, TUN state, listeners, and ProxyBridge state. Back up files before edits.
2. Check available candidate nodes using the actual target service's minimal, permitted request. A node label, latency, IP geolocation, or generic website success is not proof that the target service accepts that exit. Do not treat a region restriction as a signal to evade provider rules; report it and use only an exit location permitted for the user's account.
3. Add a dedicated manual selector group in a subscription-safe Clash Verge Rev merge/script layer. Add one unused loopback-only mixed listener with `proxy: <selector-group>`. Preserve the existing `7890` listener, global rules, and TUN setting. Avoid hard-coding `7891`; verify it is unused first.
4. In ProxyBridge, configure an upstream SOCKS5 endpoint to the dedicated listener (or HTTP only if the listener is configured for HTTP). Add a PROXY rule for the target app and each observed network helper. Put DIRECT exceptions for loopback and user-identified LAN/company resources before a broad app rule. Leave unrelated applications unmatched/DIRECT.
5. Test an app request, inspect ProxyBridge logs for the exact originating app/helper and PROXY action, and inspect Clash connections/group selection. Also test one unrelated direct request and the user's required LAN/company resource, when the user provides one. Record each result separately.
6. If traffic does not match or the target request fails, diagnose the actual process, rule order, DNS/UDP behavior, listener, chosen node, and service response before changing global networking. Stop after a small number of distinct candidates; summarize failures instead of cycling indefinitely.
7. Report the route, port, group and selected node, evidence, LAN result, known limitations, and exact rollback steps.

## Boundaries

- Never enable Clash TUN, change the system-wide proxy, rewrite the normal `7890` listener, or change unrelated app rules unless the user explicitly asks.
- Bind the dedicated listener to `127.0.0.1` (or `::1` when needed), not `0.0.0.0`, unless the user explicitly requests LAN exposure and understands the risk.
- Do not assume all app traffic is proxied from a rule that matches the main bundle only. Verify helpers in ProxyBridge Connections and add only the necessary rules.
- macOS ProxyBridge uses a Network Extension. Before installing, enabling, or approving it, obtain the user's explicit approval for that system-level networking change. Approval is specific to the current operation; the skill does not grant future approvals.
- Keep loopback direct so ProxyBridge's own connection to Clash is not sent back into ProxyBridge. Do not put a broad catch-all PROXY rule above LAN exceptions.
- Do not claim a corporate intranet works because a gateway ping or a generic private IP succeeded. Test the actual service endpoint the user names.
- If the app uses a separate VPN/network extension or a transport ProxyBridge cannot match, explain the limitation and propose a narrowly scoped next step instead of silently switching to TUN or a global proxy.

## Reference

For the exact setup, rule order, test matrix, known limitations, and rollback, read [references/proxy-runbook.md](references/proxy-runbook.md).
