---
name: app-proxy-routing
description: Configure and verify per-application proxy routing on macOS with Clash Verge Rev and ProxyBridge, including dedicated listeners, app-specific rules, and an on-demand refresh of candidate or target-app-verified nodes after subscription changes. Use when a user asks to route one app or agent through a chosen Clash proxy group without changing other apps' existing routes, or to check which nodes can reach its service.
metadata:
  short-description: macOS per-app proxy routing
---

# App Proxy Routing (macOS)

Use this skill when a user wants one application—such as Antigravity (`agy`)—to use a verified Clash Verge Rev proxy group without changing unrelated applications' pre-existing routes.

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
2. Separate subscription inventory, unauthenticated domain reachability, and target-app verification. A node in the subscription or a latency pass is only a candidate. For bulk screening, prefer the domain-probe method in the runbook: close the target app and its network helpers, then make a small unauthenticated HTTPS request to a host observed in the app's ProxyBridge logs through the dedicated listener. This can screen DNS/TCP/TLS/HTTP reachability without sending the signed-in app's request from every candidate IP. It does not prove the app/account accepts the exit. Use the app-level method only when the user wants that stronger check; explain that it sends authenticated traffic from the selected egress, avoid rapid IP rotation, and test candidates sequentially within the user's explicit budget. Do not treat a region restriction as a signal to evade provider rules; report it and use only exits permitted for the user's account.
3. Decide customization scope and result assurance from the user's request. Default to the target profile's Merge/Script so unrelated profiles are untouched. Use global extension layers only when the user asks for the route to exist across profiles. Inspect existing groups and listeners first. Reuse valid objects and create only missing or invalid ones in a subscription-safe layer. If subscription node labels can change, dynamically rebuild the candidate inventory from the current profile's `proxies` entries. Keep the production selector limited to the assurance level the user chose: domain-probe passes are only network-reachable; reserve `target-app-verified` for app-level passes. Do not bake exact subscription names into a candidate inventory or mistake inventory for verification. Set the listener's `proxy: <selector-group>`. Preserve the existing `7890` listener, global rules, and TUN setting. Avoid hard-coding `7891`; verify a port is unused before creating a listener.
4. In ProxyBridge, configure an upstream SOCKS5 endpoint to the dedicated listener (or HTTP only if the listener is configured for HTTP). Add a PROXY rule for the target app and each observed network helper. A `Target Hosts = *` (or equivalent wildcard) matches any remote destination for that matching app/process; it does not match other apps, and it cannot catch a helper process that ProxyBridge identifies separately. Put DIRECT exceptions for loopback and user-identified LAN/company resources before a broad app rule. Leave unrelated applications unmatched in ProxyBridge so their prior path is preserved.
5. Keep Clash Verge/Mihomo and ProxyBridge running while using the routed app. The macOS system proxy does not need to be enabled for ProxyBridge's explicit per-app rules to send matching connections to the dedicated listener. Saving a ProxyBridge rule applies to new connections immediately; existing long-lived app connections may retain their old route, so restart the target app/helper if a fresh connection is needed. ProxyBridge itself normally does not need restarting after a rule edit.
6. For a node refresh, record each candidate's test mode. Domain probes can populate a `network-reachable` set; app-level requests can populate a stronger `target-app-verified` set. Never label a domain-probe result as software-verified. After the batch, update the production selector according to the user's requested assurance level, keep a known-good selected node if it still exists, and make an app-level request only when requested/authorized and safe for the signed-in account. Also test one unrelated direct request and the user's required LAN/company resource, when the user provides one. Record each result separately.
7. If traffic does not match or the target request fails, diagnose the actual process, rule order, DNS/UDP behavior, listener, chosen node, and service response before changing global networking. Stop after a small number of distinct candidates; summarize failures instead of cycling indefinitely.
8. Report the route, port, group and selected node, evidence, LAN result, known limitations, and exact rollback steps.

## Boundaries

- Never enable Clash TUN, change the system-wide proxy, rewrite the normal `7890` listener, or change unrelated app rules unless the user explicitly asks.
- Bind the dedicated listener to `127.0.0.1` (or `::1` when needed), not `0.0.0.0`, unless the user explicitly requests LAN exposure and understands the risk.
- A wildcard target-host rule means any destination host for the app/process selected by the rule. It does not by itself cover all software traffic: verify helper processes in ProxyBridge Connections and add rules for the actual processes that originate requests. ProxyBridge's macOS UDP rules match the app but do not filter by host or port.
- Never move a profile-specific Merge/Script directly into global scope without testing every profile it will affect. A global Script must derive members from each profile's available proxies and ensure every referenced proxy/group exists; its listener must not point to a missing selector. If a profile has no eligible node, skip/disable that profile's route cleanly instead of using a nonexistent fallback. Validate switching profiles and refreshing a remote subscription before claiming the global setup is durable.
- Dynamic membership handles node additions/removals/renames, but it does not prove a newly added node can reach the target service or that the current selected node remains valid. After each subscription refresh, verify the selected member still exists and repeat the target-app request on any newly selected node before calling the route service-verified.
- This Skill is on-demand; it does not run in the background or receive a subscription-update event. A profile/global Script can refresh candidate membership whenever Clash Verge rebuilds a profile, but only this Skill's explicit verification workflow can test target-app access and update the verified set. If the user wants unattended post-update testing, design and authorize a separate watcher/automation with a bounded request budget.
- A successful unauthenticated domain probe proves only that the selected route received an HTTP response from that host. Statuses such as 401, 403, 404, or 405 may be expected for an unauthenticated HEAD request; report the exact status and do not call it target-app availability. Never send cookies, bearer tokens, account credentials, or app session data in a probe.
- macOS ProxyBridge uses a Network Extension. Before installing, enabling, or approving it, obtain the user's explicit approval for that system-level networking change. Approval is specific to the current operation; the skill does not grant future approvals.
- Keep loopback direct so ProxyBridge's own connection to Clash is not sent back into ProxyBridge. Do not put a broad catch-all PROXY rule above LAN exceptions.
- ProxyBridge DIRECT or no-match returns traffic to macOS; it does not override a macOS system proxy that an application honors. Inspect and preserve the existing Clash system-proxy state, and describe unrelated applications as staying on their prior route rather than guaranteeing direct internet access.
- Do not claim a corporate intranet works because a gateway ping or a generic private IP succeeded. Test the actual service endpoint the user names.
- If the app uses a separate VPN/network extension or a transport ProxyBridge cannot match, explain the limitation and propose a narrowly scoped next step instead of silently switching to TUN or a global proxy.

## Reference

For the exact setup, rule order, test matrix, known limitations, and rollback, read [references/proxy-runbook.md](references/proxy-runbook.md).
