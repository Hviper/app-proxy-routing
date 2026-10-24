#!/usr/bin/env bash
set -u

usage() {
  printf 'Usage: %s <loopback-proxy-url> <https-url-without-query-or-fragment>\n' "${0##*/}" >&2
  printf 'Example: %s http://127.0.0.1:7891 https://play.googleapis.com/\n' "${0##*/}" >&2
}

if [ "$#" -ne 2 ]; then
  usage
  exit 2
fi

proxy_url=$1
target_url=$2

target_host=$(python3 - "$proxy_url" "$target_url" <<'PY'
import sys
from urllib.parse import urlsplit

proxy = urlsplit(sys.argv[1])
target = urlsplit(sys.argv[2])
if proxy.scheme not in {"http", "socks5", "socks5h"}:
    raise SystemExit("proxy scheme must be http, socks5, or socks5h")
if proxy.hostname not in {"127.0.0.1", "localhost", "::1"} or proxy.port is None:
    raise SystemExit("proxy must be a loopback URL with an explicit port")
if proxy.username is not None or proxy.password is not None:
    raise SystemExit("do not place proxy credentials in the URL")
if target.scheme != "https" or not target.hostname:
    raise SystemExit("target must be an HTTPS URL")
if target.username is not None or target.password is not None or target.query or target.fragment:
    raise SystemExit("target URL must not contain credentials, query parameters, or a fragment")
print(target.hostname)
PY
) || exit 2

set +e
probe_result=$(curl \
  --silent --show-error \
  --head \
  --proxy "$proxy_url" \
  --noproxy '' \
  --connect-timeout 5 \
  --max-time 12 \
  --output /dev/null \
  --write-out 'http_status=%{http_code} origin_ip=%{remote_ip} connect_s=%{time_connect} tls_s=%{time_appconnect} total_s=%{time_total}' \
  "$target_url")
curl_exit=$?
set -e

if [ "$curl_exit" -eq 0 ]; then
  result=network-reachable
else
  result=probe-failed
fi

printf 'target_host=%s result=%s curl_exit=%s %s\n' "$target_host" "$result" "$curl_exit" "$probe_result"
exit "$curl_exit"
