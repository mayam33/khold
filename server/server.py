#!/usr/bin/env python3
"""Khold level server — a tiny, dependency-free JSON API.

Run:
    python server/server.py --host 0.0.0.0 --port 8787

Storage is a local SQLite database next to this file. No accounts are needed:
players publish levels, rate them (one rating per device id) and report them.
Three distinct reports hide a level from the public list.
"""

from __future__ import annotations

import argparse
import json
import secrets
import socket
import sqlite3
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

MAX_BODY = 256 * 1024
MAX_NAME = 60
MAX_AUTHOR = 40
MIN_W, MAX_W = 7, 24
MIN_H, MAX_H = 7, 32
ALLOWED = set(". SRFE#*PpEeFfRrSs")
REPORT_HIDE_THRESHOLD = 3

LOCK = threading.Lock()
DB_PATH = Path(__file__).with_name("khold.db")


def connect() -> sqlite3.Connection:
    con = sqlite3.connect(DB_PATH, check_same_thread=False)
    con.row_factory = sqlite3.Row
    return con


DB = connect()


def init_db() -> None:
    with LOCK:
        DB.executescript(
            """
            CREATE TABLE IF NOT EXISTS levels (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                author TEXT NOT NULL,
                data TEXT NOT NULL,
                created_at REAL NOT NULL,
                plays INTEGER NOT NULL DEFAULT 0,
                hidden INTEGER NOT NULL DEFAULT 0,
                rating_sum REAL NOT NULL DEFAULT 0,
                rating_count INTEGER NOT NULL DEFAULT 0
            );
            CREATE TABLE IF NOT EXISTS ratings (
                level_id TEXT NOT NULL,
                client TEXT NOT NULL,
                score INTEGER NOT NULL,
                PRIMARY KEY (level_id, client)
            );
            CREATE TABLE IF NOT EXISTS reports (
                level_id TEXT NOT NULL,
                client TEXT NOT NULL,
                reason TEXT NOT NULL,
                created_at REAL NOT NULL,
                PRIMARY KEY (level_id, client)
            );
            """
        )
        DB.commit()


def validate_level(payload: dict) -> str | None:
    name = str(payload.get("name", "")).strip()
    author = str(payload.get("author", "")).strip()
    if not name or len(name) > MAX_NAME:
        return "اسم المرحلة مطلوب (حتى 60 حرفًا)."
    if not author or len(author) > MAX_AUTHOR:
        return "اسم المؤلف مطلوب (حتى 40 حرفًا)."
    data = payload.get("data")
    if not isinstance(data, dict):
        return "بيانات المرحلة مفقودة."
    rows = data.get("rows")
    if not isinstance(rows, list) or not rows or not all(isinstance(r, str) for r in rows):
        return "صفوف المرحلة غير صالحة."
    h = len(rows)
    w = len(rows[0])
    if not (MIN_W <= w <= MAX_W and MIN_H <= h <= MAX_H):
        return "أبعاد المرحلة غير مدعومة."
    if any(len(r) != w for r in rows):
        return "صفوف المرحلة غير متساوية الطول."
    joined = "".join(rows)
    if len(joined) > MAX_W * MAX_H:
        return "المرحلة كبيرة جدًا."
    if any(ch not in ALLOWED for ch in joined):
        return "تحتوي المرحلة على رموز غير مسموحة."
    if joined.count("P") + joined.count("p") != 1:
        return "يجب أن تحتوي المرحلة على نقطة بداية واحدة."
    if joined.count("E") + joined.count("e") != 1:
        return "يجب أن تحتوي المرحلة على مخرج واحد."
    if joined.count("F") + joined.count("f") + joined.count("*") < 1:
        return "يجب أن تحتوي المرحلة على ثمرة واحدة على الأقل."
    if len(json.dumps(data, ensure_ascii=False)) > MAX_BODY:
        return "بيانات المرحلة كبيرة جدًا."
    return None


class Handler(BaseHTTPRequestHandler):
    server_version = "KholdLevelServer/1.0"

    def log_message(self, fmt: str, *args) -> None:  # quiet, keep stderr useful
        print("%s - %s" % (self.address_string(), fmt % args))

    # ------------------------------------------------------------ helpers
    def _cors(self) -> None:
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Accept")

    def _json(self, code: int, payload: dict) -> None:
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self._cors()
        self.end_headers()
        self.wfile.write(body)

    def _error(self, code: int, message: str) -> None:
        self._json(code, {"ok": False, "error": message})

    def _read_json(self):
        try:
            length = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            length = 0
        if length <= 0:
            return {}
        if length > MAX_BODY:
            raise ValueError("body too large")
        raw = self.rfile.read(length)
        try:
            return json.loads(raw.decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError):
            raise ValueError("invalid json")

    def _client(self, payload: dict) -> str:
        cid = str(payload.get("client", "")).strip()
        if not cid or len(cid) > 64:
            cid = "ip:" + self.client_address[0]
        return cid

    @staticmethod
    def _level_row(row: sqlite3.Row) -> dict:
        rating = 0.0
        if row["rating_count"]:
            rating = round(float(row["rating_sum"]) / float(row["rating_count"]), 2)
        return {
            "id": row["id"],
            "name": row["name"],
            "author": row["author"],
            "created_at": row["created_at"],
            "plays": row["plays"],
            "rating": rating,
            "rating_count": row["rating_count"],
        }

    # ------------------------------------------------------------ methods
    def do_OPTIONS(self) -> None:
        self.send_response(204)
        self._cors()
        self.send_header("Content-Length", "0")
        self.end_headers()

    def do_GET(self) -> None:
        parsed = urlparse(self.path)
        parts = [p for p in parsed.path.split("/") if p]
        try:
            if parsed.path == "/" or parsed.path == "":
                body = (
                    "Khold level server is running.\n"
                    "API: GET /health, GET /levels, GET /levels/{id}\n"
                ).encode("utf-8")
                self.send_response(200)
                self.send_header("Content-Type", "text/plain; charset=utf-8")
                self.send_header("Content-Length", str(len(body)))
                self._cors()
                self.end_headers()
                self.wfile.write(body)
                return
            if parts == ["health"]:
                self._json(200, {"ok": True, "levels": self._count_visible()})
                return
            if parts == ["levels"]:
                self._list_levels(parsed)
                return
            if len(parts) == 2 and parts[0] == "levels":
                self._get_level(parts[1])
                return
            self._error(404, "المسار غير موجود.")
        except Exception as exc:  # pragma: no cover - defensive
            print("GET error:", exc)
            self._error(500, "خطأ داخلي في الخادم.")

    def do_POST(self) -> None:
        parsed = urlparse(self.path)
        parts = [p for p in parsed.path.split("/") if p]
        try:
            payload = self._read_json()
        except ValueError:
            self._error(413, "الطلب كبير جدًا أو غير صالح.")
            return
        if not isinstance(payload, dict):
            self._error(400, "صيغة الطلب غير صالحة.")
            return
        try:
            if parts == ["levels"]:
                self._create_level(payload)
                return
            if len(parts) == 3 and parts[0] == "levels":
                action = parts[2]
                if action == "rate":
                    self._rate(parts[1], payload)
                    return
                if action == "report":
                    self._report(parts[1], payload)
                    return
                if action == "play":
                    self._play(parts[1])
                    return
            self._error(404, "المسار غير موجود.")
        except Exception as exc:  # pragma: no cover - defensive
            print("POST error:", exc)
            self._error(500, "خطأ داخلي في الخادم.")

    # ------------------------------------------------------------ routes
    def _count_visible(self) -> int:
        with LOCK:
            row = DB.execute("SELECT COUNT(*) AS c FROM levels WHERE hidden=0").fetchone()
        return int(row["c"])

    def _list_levels(self, parsed) -> None:
        query = parse_qs(parsed.query)
        try:
            limit = max(1, min(100, int(query.get("limit", ["50"])[0])))
            offset = max(0, int(query.get("offset", ["0"])[0]))
        except ValueError:
            limit, offset = 50, 0
        with LOCK:
            rows = DB.execute(
                "SELECT * FROM levels WHERE hidden=0 ORDER BY created_at DESC LIMIT ? OFFSET ?",
                (limit, offset),
            ).fetchall()
            total = DB.execute("SELECT COUNT(*) AS c FROM levels WHERE hidden=0").fetchone()["c"]
        self._json(200, {"ok": True, "levels": [self._level_row(r) for r in rows], "total": total})

    def _get_level(self, level_id: str) -> None:
        with LOCK:
            row = DB.execute("SELECT * FROM levels WHERE id=?", (level_id,)).fetchone()
        if row is None or row["hidden"]:
            self._error(404, "المرحلة غير موجودة.")
            return
        try:
            data = json.loads(row["data"])
        except json.JSONDecodeError:
            self._error(500, "بيانات المرحلة تالفة.")
            return
        payload = self._level_row(row)
        payload["data"] = data
        self._json(200, payload)

    def _create_level(self, payload: dict) -> None:
        error = validate_level(payload)
        if error:
            self._error(400, error)
            return
        level_id = secrets.token_hex(6)
        name = str(payload["name"]).strip()
        author = str(payload["author"]).strip()
        data = payload["data"]
        # Keep only the fields we understand.
        clean = {
            "w": int(len(data["rows"][0])),
            "h": int(len(data["rows"])),
            "rows": data["rows"],
            "par": int(data.get("par", 0) or 0),
        }
        now = time.time()
        with LOCK:
            DB.execute(
                "INSERT INTO levels (id, name, author, data, created_at) VALUES (?,?,?,?,?)",
                (level_id, name, author, json.dumps(clean, ensure_ascii=False), now),
            )
            DB.commit()
        print("Published %s by %s (%dx%d)" % (level_id, author, clean["w"], clean["h"]))
        self._json(201, {"ok": True, "id": level_id})

    def _rate(self, level_id: str, payload: dict) -> None:
        try:
            score = int(payload.get("score", 0))
        except (TypeError, ValueError):
            score = 0
        if score < 1 or score > 5:
            self._error(400, "التقييم يجب أن يكون من 1 إلى 5.")
            return
        client = self._client(payload)
        with LOCK:
            row = DB.execute("SELECT hidden FROM levels WHERE id=?", (level_id,)).fetchone()
            if row is None or row["hidden"]:
                self._error(404, "المرحلة غير موجودة.")
                return
            DB.execute(
                "INSERT INTO ratings (level_id, client, score) VALUES (?,?,?) "
                "ON CONFLICT(level_id, client) DO UPDATE SET score=excluded.score",
                (level_id, client, score),
            )
            agg = DB.execute(
                "SELECT SUM(score) AS s, COUNT(*) AS c FROM ratings WHERE level_id=?",
                (level_id,),
            ).fetchone()
            total = float(agg["s"] or 0)
            count = int(agg["c"] or 0)
            DB.execute(
                "UPDATE levels SET rating_sum=?, rating_count=? WHERE id=?",
                (total, count, level_id),
            )
            DB.commit()
        rating = round(total / count, 2) if count else 0.0
        self._json(200, {"ok": True, "rating": rating, "rating_count": count})

    def _report(self, level_id: str, payload: dict) -> None:
        client = self._client(payload)
        reason = str(payload.get("reason", ""))[:120]
        with LOCK:
            row = DB.execute("SELECT hidden FROM levels WHERE id=?", (level_id,)).fetchone()
            if row is None:
                self._error(404, "المرحلة غير موجودة.")
                return
            DB.execute(
                "INSERT OR IGNORE INTO reports (level_id, client, reason, created_at) VALUES (?,?,?,?)",
                (level_id, client, reason, time.time()),
            )
            count = DB.execute(
                "SELECT COUNT(*) AS c FROM reports WHERE level_id=?", (level_id,)
            ).fetchone()["c"]
            hidden = 1 if count >= REPORT_HIDE_THRESHOLD else 0
            if hidden:
                DB.execute("UPDATE levels SET hidden=1 WHERE id=?", (level_id,))
            DB.commit()
        self._json(200, {"ok": True, "reports": int(count), "hidden": bool(hidden)})

    def _play(self, level_id: str) -> None:
        with LOCK:
            DB.execute("UPDATE levels SET plays=plays+1 WHERE id=?", (level_id,))
            DB.commit()
        self._json(200, {"ok": True})


def lan_ip() -> str:
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except OSError:
        return "127.0.0.1"


def main() -> None:
    global DB_PATH, DB
    parser = argparse.ArgumentParser(description="Khold level server")
    parser.add_argument("--host", default="0.0.0.0")
    parser.add_argument("--port", type=int, default=8787)
    parser.add_argument("--db", default=str(DB_PATH))
    args = parser.parse_args()

    DB_PATH = Path(args.db)
    DB = connect()
    init_db()

    server = ThreadingHTTPServer((args.host, args.port), Handler)
    print("Khold level server listening on http://%s:%d" % (args.host, args.port))
    if args.host in ("0.0.0.0", "::"):
        print("LAN URL for phones: http://%s:%d" % (lan_ip(), args.port))
    print("Database:", DB_PATH)
    print("Press Ctrl+C to stop.")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopping.")
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
