# Pangolin health checks stuck "unhealthy" → "no available server"

**Date:** 2026-10-24
**Status:** Worked around by disabling health checks. Root cause not confirmed.

## Environment

| Component | Version |
|---|---|
| Pangolin | `fosrl/pangolin:ee-1.25.3` (issue also seen on `ee-1.18.4`) |
| Newt | `fosrl/newt:1.19.0` (Docker, `services/core/docker-compose.yml`) |
| Site | 1 Newt site (siteId 2), 7 public resources, 8 targets, one target per resource |

Newt is attached to one `gateway-<service>-resource` network per service. Each target container shares exactly one of those networks with Newt.

## Symptom

- Public resources intermittently return Traefik's **`no available server`**.
- The Pangolin dashboard shows the target's health check as **failing**.
- The service itself is up and answers its health endpoint.

`no available server` means Pangolin removed every target behind the route because each was marked unhealthy. Every resource has a single target, so one unhealthy status takes the whole resource down.

## What was checked

| Check | Result |
|---|---|
| [newt#438](https://github.com/fosrl/newt/issues/438): Newt dials an unreachable IP when a target shares several networks with Newt | **Ruled out.** Each target shares one network with Newt and container names are unique. The errors seen were DNS failures, not dial timeouts. |
| Health endpoints from inside the Newt container (`docker exec newt wget -S -O- http://<target>/<path>`) | **200 OK** (e.g. `dagu:8080/api/v1/health`, `100terres-com-proxy:80/health`). |
| Newt logs | All targets report `healthy` from 19:25:09 on, with no later failures. No `unexpected status code` lines, so [pangolin#3444](https://github.com/fosrl/pangolin/issues/3444) doesn't apply. |
| Newt restarts | `RestartCount 0`; Newt is not crashing. |
| Gerbil logs | Peer removed and re-added (new key) on each Newt start; this is expected and the tunnel came back in about 2 seconds. |
| Pangolin logs | Only Next.js `failed-to-find-server-action` errors from internet scanners (`Next-Action: x/0/1/action`), which are unrelated. |
| Health-check IDs | Consistent: Pangolin sends `targetHealthCheckId` to Newt and looks up the same ID when Newt reports. |
| Pangolin DB (`targetHealthCheck`) | IDs 2–9, all on siteId 2. Matches what Newt logs. |
| `grep 'Marking (site\|health check)'` on Pangolin logs | **No matches.** These logs may only cover the current container's lifetime. |

### Expected startup noise (not the bug)

`bin/up` starts `core` (Newt) first, then each service in turn. For about 90 seconds Newt logs `lookup <name> on 127.0.0.11:53: server misbehaving`, because the target containers don't exist yet. Targets become healthy in the order `bin/up` starts them. During that window, resources with health checks enabled correctly return `no available server`.

## Best hypothesis (unconfirmed)

Found by reading the source: Pangolin `04bf1e1` (2026-10-23) and Newt `329d6a1` (2026-10-20).

1. When Pangolin marks a site offline, `fireSiteOfflineAlert` (`server/lib/alerts/events/siteEvents.ts`) sets **every enabled health check on the site to `unhealthy`**. Two paths call it:
   - `handleNewtDisconnectingMessage`, which runs because Newt sends `newt/disconnecting` on every shutdown (`newt/newt.go:275`).
   - `offlineChecker.ts`, when pings are stale and there's no active websocket.
2. When the site comes back online, nothing resets those health checks. Newt has a `newt/healthcheck/status/request` handler that resends its full status (`newt/handlers.go:518`), but **the Pangolin server never sends that request**.
3. Newt only reports status at first check, when a status changes, and on a websocket reconnect while the tunnel is up (`newt/handlers.go:897`). If Pangolin's `unhealthy` write lands after Newt's last report, the targets stay unhealthy until Newt restarts or a status changes.

**Evidence against:** no `Marking …` lines in the Pangolin logs, possibly because the logs had rotated or the container had been recreated.

**Suggested upstream fix:** when a site transitions offline→online, Pangolin should send `newt/healthcheck/status/request`.

## Workaround applied

Health checks disabled on the targets (`hcEnabled = 0`, `hcHealth = unknown`). With one target per resource there is no failover to lose, so a health check could only take a resource offline.

```
2|2|2|0|unknown|self-hosting-demo|80
3|3|2|0|unknown|forgejo|3000
4|4|2|1|healthy|self-hosting-demo|80   ← still enabled; duplicate of #2
5|5|2|0|unknown|personal-mastodon-instance-web|3000
6|6|2|0|unknown|personal-mastodon-instance-streaming|4000
7|7|2|0|unknown|dagu|8080
8|8|2|0|unknown|widgets-proxy|80
9|9|2|0|unknown|100terres-com-proxy|80
```

## Follow-ups

- [ ] Delete the duplicate `self-hosting-demo:80` target (#4), or disable its health check.
- [ ] Watch for a few days. If resources still flake with every check disabled, the problem is in the tunnel or routing. To catch it, run this from outside the network:
  ```bash
  while true; do echo "$(date -u +%T) $(curl -s -o /dev/null -m 30 -w '%{http_code} %{time_total}s' https://<resource>/health)"; sleep 5; done
  ```
  Candidates: [newt#420](https://github.com/fosrl/newt/issues/420) and [pangolin#3818](https://github.com/fosrl/pangolin/issues/3818).
- [ ] To report upstream: re-enable one non-critical health check, set `app.log_level: "debug"` in Pangolin's `config.yml`, wait for it to get stuck, then collect:
  - Pangolin: `docker logs pangolin 2>&1 | grep -E 'health status|Health status|healthcheck|Marking'`
  - Newt: `docker logs newt 2>&1 | grep -E 'Target [0-9]+'`
  - DB: `sqlite3 -readonly config/db/db.sqlite 'select targetHealthCheckId, hcEnabled, hcHealth from targetHealthCheck;'`

## References

- [newt#438](https://github.com/fosrl/newt/issues/438): wrong IP with multiple shared networks (ruled out)
- [pangolin#3444](https://github.com/fosrl/pangolin/issues/3444): expected status code collision between targets sharing `host:port`
- [pangolin#2694](https://github.com/fosrl/pangolin/issues/2694): health check enabled → `no available server`
- [pangolin#2700](https://github.com/fosrl/pangolin/issues/2700): added the "mark targets unhealthy when site is down" behaviour
- [pangolin#3818](https://github.com/fosrl/pangolin/issues/3818): resources lost after Newt/Docker restart until Pangolin restarts
- [newt#420](https://github.com/fosrl/newt/issues/420): first request after idle stalls
