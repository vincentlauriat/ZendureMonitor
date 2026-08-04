#!/usr/bin/env python3
"""Zendure SolarFlow 24/7 collector.

Polls the device's local zenSDK API (GET /properties/report), integrates daily
solar energy into SQLite, and serves a tiny JSON API for the ZendureMonitor app:

    GET /health          -> {"ok": true, "device": "...", "lastSample": ts}
    GET /today           -> {"day": "2026-08-04", "wh": 5123}
    GET /daily?days=90   -> [{"day": "...", "wh": ...}, ...] oldest first
    GET /recent?minutes=60 -> [{"ts": ..., "solar": ..., "home": ..., "soc": ...}, ...]

Designed to run as a LaunchAgent on an always-on Mac (stdlib only, Python 3.9+).
Config via environment: ZENDURE_HOST, COLLECTOR_PORT (8899), COLLECTOR_DB.
"""

import json
import os
import sqlite3
import threading
import time
import urllib.request
from datetime import datetime, timedelta
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs

DEVICE_HOST = os.environ.get("ZENDURE_HOST", "192.168.68.46")
PORT = int(os.environ.get("COLLECTOR_PORT", "8899"))
DB_PATH = os.environ.get(
    "COLLECTOR_DB",
    os.path.expanduser("~/Library/Application Support/ZendureCollector/data.sqlite"),
)
POLL_SECONDS = 30
SAMPLE_RETENTION_DAYS = 7
DAILY_RETENTION_DAYS = 730

_lock = threading.Lock()


def db():
    conn = sqlite3.connect(DB_PATH)
    conn.execute(
        "CREATE TABLE IF NOT EXISTS samples (ts INTEGER PRIMARY KEY, solar REAL, home REAL,"
        " grid REAL, pack_in REAL, pack_out REAL, soc REAL)"
    )
    conn.execute("CREATE TABLE IF NOT EXISTS daily (day TEXT PRIMARY KEY, wh REAL)")
    return conn


def fetch_report():
    url = "http://%s/properties/report" % DEVICE_HOST
    with urllib.request.urlopen(url, timeout=8) as resp:
        data = json.load(resp)
    props = data.get("properties", data)
    return {
        "solar": float(props.get("solarInputPower", 0) or 0),
        "home": float(props.get("outputHomePower", 0) or 0),
        "grid": float(props.get("gridInputPower", 0) or 0),
        "pack_in": float(props.get("packInputPower", 0) or 0),
        "pack_out": float(props.get("outputPackPower", 0) or 0),
        "soc": float(props.get("electricLevel", 0) or 0),
    }


def poll_loop():
    last_ts = None
    while True:
        try:
            sample = fetch_report()
            now = time.time()
            day = datetime.fromtimestamp(now).strftime("%Y-%m-%d")
            with _lock:
                conn = db()
                conn.execute(
                    "INSERT OR REPLACE INTO samples VALUES (?,?,?,?,?,?,?)",
                    (int(now), sample["solar"], sample["home"], sample["grid"],
                     sample["pack_in"], sample["pack_out"], sample["soc"]),
                )
                if last_ts is not None:
                    dt = min(now - last_ts, POLL_SECONDS * 3)
                    if dt > 0:
                        wh = sample["solar"] * dt / 3600.0
                        conn.execute(
                            "INSERT INTO daily VALUES (?, ?) ON CONFLICT(day)"
                            " DO UPDATE SET wh = wh + excluded.wh",
                            (day, wh),
                        )
                # Pruning
                conn.execute("DELETE FROM samples WHERE ts < ?",
                             (int(now - SAMPLE_RETENTION_DAYS * 86400),))
                conn.execute("DELETE FROM daily WHERE day < ?",
                             ((datetime.now() - timedelta(days=DAILY_RETENTION_DAYS)).strftime("%Y-%m-%d"),))
                conn.commit()
                conn.close()
            last_ts = now
        except Exception as exc:
            last_ts = None  # gap: don't credit energy across the outage
            print("poll error: %r" % exc, flush=True)
        time.sleep(POLL_SECONDS)


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def _json(self, payload, code=200):
        body = json.dumps(payload).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        parsed = urlparse(self.path)
        query = parse_qs(parsed.query)
        with _lock:
            conn = db()
            try:
                if parsed.path == "/health":
                    row = conn.execute("SELECT MAX(ts) FROM samples").fetchone()
                    self._json({"ok": True, "device": DEVICE_HOST, "lastSample": row[0]})
                elif parsed.path == "/today":
                    day = datetime.now().strftime("%Y-%m-%d")
                    row = conn.execute("SELECT wh FROM daily WHERE day = ?", (day,)).fetchone()
                    self._json({"day": day, "wh": round(row[0], 1) if row else 0})
                elif parsed.path == "/daily":
                    days = int(query.get("days", ["90"])[0])
                    since = (datetime.now() - timedelta(days=days)).strftime("%Y-%m-%d")
                    rows = conn.execute(
                        "SELECT day, wh FROM daily WHERE day >= ? ORDER BY day", (since,)
                    ).fetchall()
                    self._json([{"day": d, "wh": round(w, 1)} for d, w in rows])
                elif parsed.path == "/recent":
                    minutes = int(query.get("minutes", ["60"])[0])
                    since = int(time.time() - minutes * 60)
                    rows = conn.execute(
                        "SELECT ts, solar, home, soc FROM samples WHERE ts >= ? ORDER BY ts",
                        (since,),
                    ).fetchall()
                    self._json([{"ts": t, "solar": s, "home": h, "soc": c} for t, s, h, c in rows])
                else:
                    self._json({"error": "not found"}, 404)
            finally:
                conn.close()


def main():
    os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)
    threading.Thread(target=poll_loop, daemon=True).start()
    ThreadingHTTPServer(("0.0.0.0", PORT), Handler).serve_forever()


if __name__ == "__main__":
    main()
