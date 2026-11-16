#!/usr/bin/env python3
"""End-to-end tests for the bundled Khold level server.

The script starts server/server.py on a free local port with a temporary
SQLite file, exercises the public API, and removes the database afterwards.

Run:
    python tools/test_server.py
"""

from __future__ import annotations

import argparse
import json
import os
import socket
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SERVER = ROOT / "server" / "server.py"
BASE_ROWS = [
    "SSSSSSSSSSSS",
    "SP........SS",
    "S....F.....S",
    "S..........S",
    "S..........S",
    "S..........S",
    "S..........S",
    "S..........S",
    "S..........S",
    "S..........S",
    "S..........S",
    "S..........S",
    "S..........S",
    "S..........S",
    "S.........ES",
    "SSSSSSSSSSSS",
]

PASSED = 0
FAILED = 0


def check(condition: bool, label: str) -> None:
    global PASSED, FAILED
    if condition:
        PASSED += 1
        print("ok:", label)
    else:
        FAILED += 1
        print("FAIL:", label)


def free_port() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
        sock.bind(("127.0.0.1", 0))
        return int(sock.getsockname()[1])


def request(base: str, method: str, path: str, body: dict | None = None):
    data = None
    # Cloudflare blocks generic Python user agents; use the same family of
    # user agent that Godot's HTTPRequest sends.
    headers = {
        "Accept": "application/json",
        "User-Agent": "GodotEngine/4.7.2 (HTTPRequest; Khold test)",
    }
    if body is not None:
        data = json.dumps(body, ensure_ascii=False).encode("utf-8")
        headers["Content-Type"] = "application/json"
    req = urllib.request.Request(base + path, data=data, headers=headers, method=method)
    def parse(raw: str):
        if not raw:
            return {}
        try:
            return json.loads(raw)
        except json.JSONDecodeError:
            return {"text": raw}

    last_error: Exception | None = None
    for attempt in range(3):
        try:
            with urllib.request.urlopen(req, timeout=15) as res:
                return res.status, parse(res.read().decode("utf-8"))
        except urllib.error.HTTPError as exc:
            return exc.code, parse(exc.read().decode("utf-8"))
        except (TimeoutError, urllib.error.URLError) as exc:
            last_error = exc
            if attempt < 2:
                time.sleep(0.4)
    raise last_error  # type: ignore[misc]


def wait_ready(base: str) -> bool:
    for _ in range(80):
        try:
            code, payload = request(base, "GET", "/health")
            if code == 200 and payload.get("ok"):
                return True
        except OSError:
            pass
        time.sleep(0.1)
    return False


def main() -> int:
    parser = argparse.ArgumentParser(description="Khold level server tests")
    parser.add_argument(
        "--base",
        default="",
        help="Test an already-running server instead of spawning server/server.py",
    )
    args = parser.parse_args()

    proc = None
    db_file = None
    if args.base:
        base = args.base.rstrip("/")
    else:
        port = free_port()
        base = f"http://127.0.0.1:{port}"
        db_file = Path(tempfile.gettempdir()) / f"khold_server_test_{os.getpid()}.db"
        if db_file.exists():
            db_file.unlink()
        proc = subprocess.Popen(
            [
                sys.executable,
                str(SERVER),
                "--host",
                "127.0.0.1",
                "--port",
                str(port),
                "--db",
                str(db_file),
            ],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    try:
        check(wait_ready(base), "server starts and answers /health")
        code, payload = request(base, "GET", "/")
        check(code == 200, "root banner answers")

        level = {
            "name": "مرحلة الاختبار",
            "author": "خُلد",
            "data": {"w": 12, "h": 16, "rows": BASE_ROWS, "par": 22},
        }
        code, payload = request(base, "POST", "/levels", level)
        check(code == 201 and payload.get("ok"), "publishes a valid level")
        level_id = str(payload.get("id", ""))
        check(len(level_id) == 12, "server returns a 12-character id")

        code, payload = request(base, "GET", "/levels")
        levels = payload.get("levels", [])
        check(code == 200 and payload.get("total") == 1, "list reports one level")
        check(levels and levels[0].get("name") == "مرحلة الاختبار", "Arabic name round-trips")
        check(levels and levels[0].get("rating_count") == 0, "new level has no ratings")

        code, payload = request(base, "GET", f"/levels/{level_id}")
        check(code == 200 and payload.get("data", {}).get("rows") == BASE_ROWS, "level payload round-trips")
        check(payload.get("data", {}).get("par") == 22, "par is preserved")

        code, payload = request(base, "POST", f"/levels/{level_id}/rate", {"score": 5, "client": "device-a"})
        check(code == 200 and payload.get("rating") == 5.0 and payload.get("rating_count") == 1, "first rating is stored")
        code, payload = request(base, "POST", f"/levels/{level_id}/rate", {"score": 3, "client": "device-a"})
        check(code == 200 and payload.get("rating") == 3.0 and payload.get("rating_count") == 1, "same client updates its rating")
        code, payload = request(base, "POST", f"/levels/{level_id}/rate", {"score": 4, "client": "device-b"})
        check(code == 200 and payload.get("rating") == 3.5 and payload.get("rating_count") == 2, "second client averages")
        code, payload = request(base, "POST", f"/levels/{level_id}/rate", {"score": 9})
        check(code == 400, "out-of-range rating is rejected")

        code, payload = request(base, "POST", f"/levels/{level_id}/report", {"reason": "spam", "client": "device-a"})
        check(code == 200 and payload.get("reports") == 1 and payload.get("hidden") is False, "first report is counted")
        request(base, "POST", f"/levels/{level_id}/report", {"reason": "spam", "client": "device-a"})
        code, payload = request(base, "POST", f"/levels/{level_id}/report", {"reason": "spam", "client": "device-b"})
        check(payload.get("reports") == 2 and payload.get("hidden") is False, "repeat report from same client is ignored")
        code, payload = request(base, "POST", f"/levels/{level_id}/report", {"reason": "spam", "client": "device-c"})
        check(payload.get("reports") == 3 and payload.get("hidden") is True, "three reports hide the level")
        code, payload = request(base, "GET", "/levels")
        check(payload.get("total") == 0 and payload.get("levels") == [], "hidden level leaves the list")
        code, payload = request(base, "GET", f"/levels/{level_id}")
        check(code == 404, "hidden level cannot be fetched")

        code, payload = request(base, "POST", "/levels", {"name": "bad", "author": "x", "data": {"rows": ["SSSS", "SPES"]}})
        check(code == 400, "undersized level is rejected")
        bad_rows = list(BASE_ROWS)
        bad_rows[0] = "XXXXSSSSSSSS"
        code, payload = request(base, "POST", "/levels", {"name": "bad", "author": "x", "data": {"rows": bad_rows}})
        check(code == 400, "unknown symbols are rejected")

        code, payload = request(base, "POST", "/levels", level)
        second_id = str(payload.get("id", ""))
        code, payload = request(base, "POST", f"/levels/{second_id}/play")
        check(code == 200, "play counter accepts a ping")
        code, payload = request(base, "GET", "/levels")
        check(payload.get("levels", [{}])[0].get("plays") == 1, "play counter is visible")

        code, payload = request(base, "GET", "/levels?limit=1&offset=0")
        check(code == 200 and len(payload.get("levels", [])) == 1, "limit/offset are applied")
        code, payload = request(base, "GET", "/nope")
        check(code == 404, "unknown path returns 404")
        code, payload = request(base, "POST", "/nope", {})
        check(code == 404, "unknown POST path returns 404")
    finally:
        if proc is not None:
            proc.terminate()
            try:
                proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                proc.kill()
        if db_file is not None and db_file.exists():
            db_file.unlink()

    print(f"\nServer test: {PASSED} checks, {FAILED} failures")
    return 1 if FAILED else 0


if __name__ == "__main__":
    sys.exit(main())
