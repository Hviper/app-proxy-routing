# Per-app proxy runbook: Clash Verge Rev + ProxyBridge (macOS)

Use this procedure when a user asks for one application (for example Antigravity) to use a chosen Clash proxy group while other applications and LAN traffic keep their current route.

## What the route means

```text
Antigravity main process / helper
        │ matching ProxyBridge rule
        ▼
ProxyBridge Network Extension
        │ SOCKS5 127.0.0.1:<dedicated-port>
        ▼
Mihomo listener: mixed, loopback-only, proxy: APP-ACCESS
        │ bypasses the ordinary rule matcher for this inbound
        ▼
APP-ACCESS selector → chosen outbound node
```

Clash's ordinary mixed port (commonly `7890`) is a proxy entrance whose requests are evaluated using the active Clash mode/rules. A Mihomo `listeners` entry can have its own `proxy` value. When set, Mihomo sends that inbound directly to the named outbound proxy/group instead of selecting an outbound through the ordinary rules. The listener and selector are configuration objects inside the existing Mihomo/Clash Verge process; they do not start a second proxy daemon. See the [Mihomo inbound/listener guide](https://wiki.metacubex.one/config/inbound/), [listener common fields](https://wiki.metacubex.one/config/inbound/listeners/), and [select groups](https://wiki.metacubex.one/config/proxy-groups/select/).

ProxyBridge's `DIRECT` or no-match action gives the connection back to macOS; it does not cancel a macOS system proxy that the app uses. If Clash's system proxy is enabled, other apps that honor it can still enter the ordinary Clash port and follow its rules. Preserve that existing setting and describe non-target apps as staying on their prior path. Do not say they are guaranteed to connect directly unless their actual route has been tested.

ProxyBridge's macOS Network Extension can match connections by bundle ID/process name, destination, port, and protocol. Rules are evaluated in order; `DIRECT` or no match leaves traffic to macOS. UDP matching on macOS is app-only, without destination host/port matching. Helper processes may originate traffic under a different name, so inspect actual connection logs. See [ProxyBridge's macOS model](https://proxybridge.interceptsuite.com/docs/macos-how-it-works/) and [macOS rule reference](https://proxybridge.interceptsuite.com/docs/macos-rules/).

### Important distinction: a reachable node is not necessarily an allowed service exit

Clash URL/latency checks establish only that the node can reach that test URL. A successful generic IP/geolocation request also does not prove Gemini/Antigravity accepts that exit. Validate with the actual target service and user's account, using a minimal request and reading the app's real response. A `User location is not supported` message may indicate the service/account does not permit that exit or that egress geolocation differs from the node's label. Do not promise that changing nodes will resolve an access restriction. Only select exits the user is permitted to use under the service's terms.

## Before editing

1. Confirm the target application and service, the relevant signed-in account is already available, and what the user means by “available” (for example, a successful minimal Gemini request). Do not ask the user to share credentials or tokens.
2. Inspect current Clash Verge Rev and Mihomo versions, active profile, current mode, TUN state, listeners/ports, and current groups. Inspect ProxyBridge's running state and existing rules. Do not assume a previous machine's configuration exists on this one.
3. Identify the target app's bundle ID and likely helper processes. Prefer the ProxyBridge Connections log while the app makes an ordinary request; the log is the source of the actual process identifier to match.
4. Back up the profile/script/merge configuration before changing it. Determine an unused local port by checking the active listeners and socket table; `7891` is only an example and may already be taken.
5. Check Clash Verge Rev's supported profile customization for the installed version. Prefer its Merge or Script layer over editing a subscription-provided base profile, so a profile refresh does not overwrite the addition. Clash Verge Rev documents these as [merge configuration](https://getclashvergerev.org/en/guide/merge.html). Validate exact behavior against installed version/profile before committing.

## Add the isolated Clash path

First inspect the active profile's groups and listeners. Reuse an existing dedicated selector and listener if both are valid and point to the intended group. Add only missing or invalid pieces; do not create duplicate groups/listeners on every run. Choose a unique group name and verified unused loopback port when creating them. The example below is only for the create-needed case: it is a Mihomo configuration fragment, not a universal paste-in patch. Proxy names must exactly match the active profile. Merge/script schemas vary by app version; inspect rendered config after applying.

### Choose profile scope or global scope

- Default to the active profile's own Merge/Script when only that profile needs this route. In Clash Verge Rev, a profile's Merge and Script are attached separately from its remote subscription content, so a normal update of that same profile should retain the association; verify the attachment after refresh and recheck candidate nodes because subscription members may change.
- Use Global Extend Config/Global Extend Script only when the user wants the support objects available across profiles. Global layers run for every applicable profile. Do not copy a profile-specific script globally without a cross-profile dry run.
- For global scope, prefer one dynamic extension script that inspects each profile's current proxy/group inventory and creates a selector and listener only when it can produce valid references. Every selector member and listener `proxy` target must exist in that profile. If a profile has no eligible nodes, skip that profile's dedicated listener cleanly; do not use a fallback group name unless it is present.
- Test the global extension against every local profile (including profiles currently inactive), then switch at least between profiles with and without eligible nodes. Verify the resulting runtime config, selector members, listener port, and connection route. Check again after a subscription update, which can add, remove, or rename proxy entries.

```yaml
proxy-groups:
  - name: APP-ACCESS
    type: select
    proxies:
      - node-name-one
      - node-name-two

listeners:
  - name: app-access-in
    type: mixed
    listen: 127.0.0.1
    port: 7891 # replace with a verified unused port
    proxy: APP-ACCESS
    udp: true
```

Guidance:

- Use a dedicated, clearly named manual `select` group for deterministic testing. Use direct proxy node entries as members during verification; avoid nested groups if you need to know exactly which node carried the request.
- Do not include `DIRECT` in the production selector unless direct fallback is an intentional user choice. Otherwise, a mistaken selection could make an “available proxy” test appear to succeed directly.
- `udp: true` permits the listener to accept UDP; it does not guarantee that ProxyBridge's SOCKS5 UDP relay or the selected upstream supports it. Test app-required UDP separately. For HTTPS API/TLS requests, TCP is usually the initial critical path.
- Bind only to `127.0.0.1` (and optionally create a separate `::1` listener if needed). Mihomo listener docs note that `0.0.0.0` exposes the inbound to all interfaces.
- Keep global mode, global rules, `7890`, and TUN unchanged. `proxy: APP-ACCESS` is the part that bypasses ordinary Clash domain/rule selection for traffic entering this listener.
- Apply the customization and confirm the active/rendered Mihomo config accepts it. Confirm the new port is listening only on loopback before configuring ProxyBridge.
- The dedicated listener and selector are objects in the existing Clash Verge/Mihomo process; they do not require a second Clash daemon. Keep Clash Verge/Mihomo running while using the app. The macOS system proxy can remain off: ProxyBridge's explicit app rule sends matching connections to its configured listener independently.

## Find and test a usable candidate

Keep tests bounded and make the app's service response the pass/fail signal.

1. Obtain candidate nodes from the existing profile. Do not fetch or import an untrusted subscription/config as part of this procedure without the user's request.
2. If there are many candidates, first filter to nodes plausibly in service-supported locations using ordinary Clash connectivity/health checks. These checks reduce work but are not final evidence. Don't infer exit location from a node's display name.
3. Select one candidate in `APP-ACCESS`. Confirm Mihomo controller/Connections reports this selector/member for flows received at `app-access-in`.
4. Trigger one minimal target-app request. Inspect the app response for success, authentication failure, timeout, or location/access restriction. Correlate the timestamp and destination in ProxyBridge Connections and Mihomo logs.
5. Mark a candidate “service-verified” only when the target app's request succeeds and the logs show the request used the dedicated listener and the intended node. A Cloudflare trace or other public IP endpoint can be recorded as supporting egress information only.
6. Test a small number of distinct candidates. If all fail with the same explicit service location restriction, stop and report that the account/service does not accept the tested exits; don't continue rotating nodes to circumvent it.
7. Leave the known-good node selected only after validation. If no node passes, don't label the route “available”; either remove/disable the candidate group and listener or leave them clearly marked experimental, based on the user's desired state.

Suggested report table:

| Candidate | Generic connectivity | Target app response | ProxyBridge + Mihomo route evidence | Result |
|---|---|---|---|---|
| node label | optional health/IP check | exact status/category, no secret content | process/helper, PROXY, listener/group | service-verified / failed / inconclusive |

## Configure ProxyBridge

1. Ensure ProxyBridge is running and its system extension is already approved. Installing/activating/approving the extension is a system-level network change and requires explicit user authorization at that time.
2. Add a proxy endpoint in ProxyBridge pointing to `127.0.0.1:<verified-port>`. SOCKS5 is a suitable choice for the Mihomo mixed listener. Enable remote DNS/hostname passing if the client has that setting and the target requires proxy-side DNS; validate with logs. Do not add authentication unless the listener requires it.
3. Add DIRECT exceptions first for loopback destinations (`127.0.0.1`, `localhost`, `::1`) so the ProxyBridge-to-Mihomo hop remains local and cannot loop back into its own Network Extension.
4. Add DIRECT exceptions for the specific user-provided company/LAN hostnames/IPs or required internal services before the broad application rule. Keep the exception narrowly scoped; ProxyBridge's macOS host/domain rules do not accept CIDR notation, so use documented range/wildcard syntax supported by its installed version or exact domains/IPs.
5. Add PROXY rules for the target's observed bundle ID and each actual helper process that needs the target service. Match only the target app/helper and necessary protocol. Use the Connections log to confirm the correct identifier; do not blanket-proxy generic executables like `node`, `python3`, or `curl` machine-wide when they can serve unrelated work.
6. Leave other apps unmatched in ProxyBridge so their prior route is preserved. ProxyBridge no-match passes traffic to macOS, where an app may still honor the system proxy; do not create a catch-all PROXY rule or claim unmatched apps bypass Clash's system proxy.
7. Check rule ordering and test with traffic logging enabled. ProxyBridge documents that its app's rules are ordered and that UDP rules on macOS only match the app, not host or port.

### Target host wildcard and rule updates

- In a ProxyBridge rule scoped to a specific app/process, `Target Hosts = *` (or the UI's equivalent any-host wildcard) matches connections from that app/process to any destination host, subject to the rule's protocol/port settings. It does not mean every process on the computer.
- If a helper process originates a request and ProxyBridge identifies it separately, a wildcard host on the main app's rule does not cover that helper. Check Connections logs and add a narrowly scoped process rule for each required helper.
- Saving/editing a ProxyBridge rule takes effect immediately for new connections. Existing long-lived connections may continue on their established route; restart the target app or its relevant helper if a fresh connection is needed. ProxyBridge itself normally does not need to restart after a rule edit. Keep ProxyBridge and its Network Extension active during use; quitting ProxyBridge stops interception.

## Acceptance tests

Record evidence separately; do not overstate what each check proves.

1. **Listener:** local socket exists on `127.0.0.1:<port>`; a local SOCKS5/HTTP handshake to it succeeds; active Clash config shows its `proxy` points to the dedicated group.
2. **Target app:** keep Clash Verge/Mihomo and ProxyBridge running; system proxy may remain off. Make a minimal request to the service. It succeeds at the app layer (not just TLS connect). In ProxyBridge logs, the target/helper shows PROXY to `127.0.0.1:<port>`; in Clash logs/connections, the request uses the dedicated listener and chosen node/group. A `*` target-host rule covers all destination hosts for the matched app/process, not helper processes that have a different process identity.
3. **Non-target app:** make a small request from an unrelated app. Confirm it is unmatched/DIRECT in ProxyBridge, then verify its actual path according to the pre-existing system-proxy configuration. If system proxy is enabled, it may still follow Clash's ordinary rules.
4. **LAN/company:** request the exact intranet service the user named. Confirm it follows DIRECT. If no actual endpoint was supplied, report “not tested”; a gateway ping is not a substitute.
5. **No route drift:** verify Clash remains in its prior mode, TUN has the prior value, and ordinary `7890` has not changed.
6. **Failure:** capture the exact error category and route evidence. Distinguish at least: app-rule mismatch/helper process, listener unreachable, node timeout, DNS resolution, authentication, service authorization, and service location restriction.

## Rollback

1. Disable/remove ProxyBridge PROXY rules for the target and helper; leave explicit LAN and loopback DIRECT exceptions if they were already part of the user's prior configuration, otherwise restore the exact backup.
2. Remove the dedicated listener and selector from the customization layer, or restore the backed-up profile/script. Apply and verify the original `7890`, mode, and TUN settings are restored.
3. Confirm the target app no longer appears as PROXY in ProxyBridge logs. If the user wants to stop interception entirely, quit ProxyBridge or disable its extension using its supported UI; do not uninstall or revoke unrelated extensions.
4. Never use rollback as a reason to change system-wide proxy settings.

## Report template

```text
Target app/helper(s):
Dedicated Clash group:
Dedicated listener: 127.0.0.1:<port> (type, protocol)
Selected node:
ProxyBridge rule result:
Target service test:
Unrelated-app direct test:
LAN/company endpoint test:
Existing 7890/mode/TUN preserved:
Remaining limitations:
Rollback steps/location of backup:
```

## Primary references

- [Mihomo inbound configuration](https://wiki.metacubex.one/en/config/inbound/)
- [Mihomo listener common fields](https://wiki.metacubex.one/en/config/inbound/listeners/)
- [Mihomo mixed listener](https://wiki.metacubex.one/en/config/inbound/listeners/mixed/)
- [Mihomo manual select group](https://wiki.metacubex.one/en/config/proxy-groups/select/)
- [Clash Verge Rev merge configuration](https://getclashvergerev.org/en/guide/merge.html)
- [ProxyBridge macOS architecture](https://proxybridge.interceptsuite.com/docs/macos-how-it-works/)
- [ProxyBridge macOS proxy rules](https://proxybridge.interceptsuite.com/docs/macos-rules/)
- [ProxyBridge macOS troubleshooting](https://proxybridge.interceptsuite.com/docs/macos-troubleshooting/)
