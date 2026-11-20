"""URL status dashboard.

Checks a list of URLs on a timer and serves the results as a web page.

Environment variables:
  URLS      comma-separated URLs (default: https://example.com,https://www.python.org)
  TIMEOUT   seconds per request (default: 10)
  INTERVAL  seconds between checks (default: 30)
  PORT      web server port (default: 8080)
  HEARTBEAT_INTERVAL  seconds between heartbeats (default: 300 = 5 minutes)
  HEARTBEAT_MAX       heartbeat rows kept in memory (default: 288 = 24h at 5 min)
  HEARTBEAT_FILE      optional path; each heartbeat is also appended there as JSON
                      lines (mount a volume to keep history across restarts)

Endpoints:
  /            HTML dashboard (auto-refreshes)
  /api/status  same data as JSON, including heartbeats
  /health      returns 200, for load balancer health checks
"""
import html
import json
import logging
import os
import platform
import resource
import socket
import threading
import time
import urllib.error
import urllib.request
from collections import deque
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger("automation")

URLS = [u.strip() for u in os.getenv("URLS", "https://example.com,https://www.python.org").split(",") if u.strip()]
TIMEOUT = float(os.getenv("TIMEOUT", "10"))
INTERVAL = max(int(os.getenv("INTERVAL", "30")), 1)
PORT = int(os.getenv("PORT", "8080"))
HEARTBEAT_INTERVAL = max(int(os.getenv("HEARTBEAT_INTERVAL", "60")), 1)
HEARTBEAT_MAX = max(int(os.getenv("HEARTBEAT_MAX", "288")), 1)
HEARTBEAT_FILE = os.getenv("HEARTBEAT_FILE", "")

START = time.monotonic()
heartbeats = deque(maxlen=HEARTBEAT_MAX)
state = {"checked_at": None, "results": []}
lock = threading.Lock()


def check(url: str) -> dict:
    start = time.monotonic()
    status, error = None, None
    try:
        with urllib.request.urlopen(url, timeout=TIMEOUT) as resp:
            status = resp.status
    except urllib.error.HTTPError as e:
        status, error = e.code, str(e)
    except Exception as e:
        error = str(e)
    ms = round((time.monotonic() - start) * 1000)
    ok = status is not None and 200 <= status < 400
    log.log(logging.INFO if ok else logging.ERROR, "%s -> %s (%d ms)", url, status or error, ms)
    return {"url": url, "status": status, "ok": ok, "error": error, "ms": ms}


def checker_loop() -> None:
    while True:
        results = [check(u) for u in URLS]
        with lock:
            state["results"] = results
            state["checked_at"] = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")
        time.sleep(INTERVAL)


def fetch_ecs_metadata() -> dict:
    """Task details from the ECS metadata endpoint. Empty when not running on ECS."""
    base = os.getenv("ECS_CONTAINER_METADATA_URI_V4")
    if not base:
        return {}
    try:
        with urllib.request.urlopen(base + "/task", timeout=2) as resp:
            task = json.load(resp)
        return {
            "task_arn": task.get("TaskARN"),
            "availability_zone": task.get("AvailabilityZone"),
            "launch_type": task.get("LaunchType"),
        }
    except Exception as e:
        log.warning("ECS metadata unavailable: %s", e)
        return {}


ECS_META = fetch_ecs_metadata()


def build_heartbeat(seq: int) -> dict:
    with lock:
        results = list(state["results"])
    return {
        "seq": seq,
        "time": datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC"),
        "uptime_s": round(time.monotonic() - START),
        "host": socket.gethostname(),
        "pid": os.getpid(),
        "python": platform.python_version(),
        "memory_mb": round(resource.getrusage(resource.RUSAGE_SELF).ru_maxrss / 1024, 1),
        "urls_up": sum(r["ok"] for r in results),
        "urls_total": len(results),
        **ECS_META,
    }


def heartbeat_loop() -> None:
    seq = 0
    while True:
        seq += 1
        beat = build_heartbeat(seq)
        with lock:
            heartbeats.append(beat)
        log.info("heartbeat #%d uptime=%ss urls_up=%s/%s", seq, beat["uptime_s"], beat["urls_up"], beat["urls_total"])
        if HEARTBEAT_FILE:
            try:
                with open(HEARTBEAT_FILE, "a") as f:
                    f.write(json.dumps(beat) + "\n")
            except OSError as e:
                log.warning("Could not write %s: %s", HEARTBEAT_FILE, e)
        time.sleep(HEARTBEAT_INTERVAL)


def render_page() -> bytes:
    with lock:
        results, checked_at = list(state["results"]), state["checked_at"]
        beats = list(heartbeats)
    rows = ""
    for r in results:
        color = "#16a34a" if r["ok"] else "#dc2626"
        label = "UP" if r["ok"] else "DOWN"
        detail = html.escape(str(r["status"] or r["error"] or ""))
        rows += (
            f"<tr><td>{html.escape(r['url'])}</td>"
            f"<td><span class='badge' style='background:{color}'>{label}</span></td>"
            f"<td>{detail}</td><td>{r['ms']} ms</td></tr>"
        )
    if not rows:
        rows = "<tr><td colspan='4'>Running first check...</td></tr>"
    up = sum(r["ok"] for r in results)
    beat_rows = ""
    for b in reversed(beats):  # newest first
        where = html.escape(str(b.get("availability_zone") or b["host"]))
        beat_rows += (
            f"<tr><td>{b['seq']}</td><td>{html.escape(b['time'])}</td><td>{b['uptime_s']}s</td>"
            f"<td>{where}</td><td>{b['pid']}</td><td>{html.escape(b['python'])}</td>"
            f"<td>{b['memory_mb']} MB</td><td>{b['urls_up']}/{b['urls_total']}</td></tr>"
        )
    if not beat_rows:
        beat_rows = "<tr><td colspan='8'>No heartbeat yet</td></tr>"
    page = f"""<!doctype html>
<html><head><meta charset="utf-8"><meta http-equiv="refresh" content="5">
<title>URL Status</title>
<style>
 body{{font-family:system-ui,sans-serif;max-width:800px;margin:2rem auto;padding:0 1rem;color:#111}}
 table{{width:100%;border-collapse:collapse}}
 th,td{{text-align:left;padding:.6rem;border-bottom:1px solid #e5e7eb}}
 .badge{{color:#fff;padding:.15rem .6rem;border-radius:999px;font-size:.85rem;font-weight:600}}
 .muted{{color:#6b7280}}
</style></head><body>
<h1>URL Status</h1>
<p class="muted">{up}/{len(results)} up. Last check: {checked_at or "pending"}. Checks every {INTERVAL}s, page refreshes every 5s.</p>
<table><tr><th>URL</th><th>State</th><th>Status</th><th>Response</th></tr>{rows}</table>
<h2>Heartbeat</h2>
<p class="muted">A new row every {HEARTBEAT_INTERVAL}s with metadata about this container. Newest first.</p>
<table><tr><th>#</th><th>Time</th><th>Uptime</th><th>Host / AZ</th><th>PID</th><th>Python</th><th>Memory</th><th>URLs up</th></tr>{beat_rows}</table>
</body></html>"""
    return page.encode()


class Handler(BaseHTTPRequestHandler):
    def _send(self, code: int, body: bytes, ctype: str) -> None:
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:
        if self.path == "/health":
            self._send(200, b"ok", "text/plain")
        elif self.path == "/api/status":
            with lock:
                body = json.dumps({**state, "heartbeats": list(heartbeats)}, indent=2).encode()
            self._send(200, body, "application/json")
        elif self.path == "/":
            self._send(200, render_page(), "text/html; charset=utf-8")
        else:
            self._send(404, b"not found", "text/plain")

    def log_message(self, *args) -> None:  # silence per-request logs
        pass


def main() -> None:
    threading.Thread(target=checker_loop, daemon=True).start()
    threading.Thread(target=heartbeat_loop, daemon=True).start()
    log.info("Dashboard on http://0.0.0.0:%d", PORT)
    ThreadingHTTPServer(("0.0.0.0", PORT), Handler).serve_forever()


if __name__ == "__main__":
    main()
