from http.server import BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs
import json
import os
import re
import sqlite3
import threading
import unicodedata

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DATA_DIR = os.path.join(BASE_DIR, "_data")
STUDENTS_DB = os.path.join(DATA_DIR, "students.db")
NAMES_DB = os.path.join(DATA_DIR, "names.db")

ARABIC_CHAR_MAP = str.maketrans({
    "أ": "ا", "إ": "ا", "آ": "ا", "ٱ": "ا",
    "ى": "ي", "ؤ": "و", "ئ": "ي", "ة": "ه", "ـ": "",
})
DIGIT_MAP = str.maketrans("٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹", "01234567890123456789")
DB_LOCK = threading.Lock()


def normalize_arabic(value: str) -> str:
    value = str(value or "").translate(DIGIT_MAP).translate(ARABIC_CHAR_MAP)
    value = "".join(
        ch for ch in unicodedata.normalize("NFKD", value)
        if not unicodedata.combining(ch)
    )
    value = re.sub(r"[^0-9A-Za-z\u0600-\u06FF ]+", " ", value)
    return re.sub(r"\s+", " ", value).strip().lower()


def open_readonly(path: str) -> sqlite3.Connection:
    uri = f"file:{path}?mode=ro&immutable=1"
    connection = sqlite3.connect(uri, uri=True, check_same_thread=False)
    connection.row_factory = sqlite3.Row
    return connection


STUDENTS = open_readonly(STUDENTS_DB)
NAMES = open_readonly(NAMES_DB)
STATUSES = {
    int(row["code"]): row["label"]
    for row in STUDENTS.execute("SELECT code, label FROM statuses")
}


def format_total(value):
    if value is None:
        return ""
    number = float(value)
    return int(number) if number.is_integer() else round(number, 2)


def row_to_result(row):
    return {
        "seat": str(row["seat_no"]),
        "name": row["name"],
        "total": format_total(row["total"]),
        "status": STATUSES.get(int(row["status_code"]), ""),
    }


def search_by_seat(seat: str):
    row = STUDENTS.execute(
        "SELECT seat_no, name, total, status_code FROM students WHERE seat_no = ? LIMIT 1",
        (int(seat),),
    ).fetchone()
    return [] if row is None else [row_to_result(row)]


def make_fts_query(name: str) -> str:
    normalized = normalize_arabic(name)
    terms = [term for term in normalized.split(" ") if term][:8]
    if not terms:
        return ""
    # Prefix matching lets a user enter a complete name or the beginning of any name part.
    return " AND ".join(f'"{term.replace(chr(34), chr(34) * 2)}"*' for term in terms)


def search_by_name(name: str, limit: int = 50):
    fts_query = make_fts_query(name)
    if not fts_query:
        return [], False

    seat_rows = NAMES.execute(
        "SELECT rowid AS seat_no FROM names_fts WHERE names_fts MATCH ? LIMIT ?",
        (fts_query, limit + 1),
    ).fetchall()

    has_more = len(seat_rows) > limit
    seat_numbers = [int(row["seat_no"]) for row in seat_rows[:limit]]
    if not seat_numbers:
        return [], False

    placeholders = ",".join("?" for _ in seat_numbers)
    details = STUDENTS.execute(
        f"SELECT seat_no, name, total, status_code FROM students WHERE seat_no IN ({placeholders})",
        seat_numbers,
    ).fetchall()
    by_seat = {int(row["seat_no"]): row_to_result(row) for row in details}
    return [by_seat[seat] for seat in seat_numbers if seat in by_seat], has_more


class handler(BaseHTTPRequestHandler):
    def send_json(self, status_code: int, payload: dict, cache: bool = False):
        body = json.dumps(payload, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
        self.send_response(status_code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Referrer-Policy", "same-origin")
        self.send_header(
            "Cache-Control",
            "public, s-maxage=300, stale-while-revalidate=3600" if cache else "no-store",
        )
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        try:
            query = parse_qs(urlparse(self.path).query)
            raw_query = (query.get("q", [""])[0] or "").strip()
            raw_seat = (query.get("seat", [""])[0] or "").strip()
            raw_name = (query.get("name", [""])[0] or "").strip()

            if raw_query and not raw_seat and not raw_name:
                normalized_query = raw_query.translate(DIGIT_MAP)
                if re.fullmatch(r"\d+", normalized_query):
                    raw_seat = normalized_query
                else:
                    raw_name = raw_query

            if raw_seat:
                seat = re.sub(r"\D", "", raw_seat.translate(DIGIT_MAP))
                if not seat or len(seat) > 12:
                    self.send_json(400, {"ok": False, "message": "رقم الجلوس غير صحيح."})
                    return
                with DB_LOCK:
                    results = search_by_seat(seat)
                self.send_json(200, {"ok": True, "type": "seat", "results": results, "hasMore": False}, cache=True)
                return

            normalized_name = normalize_arabic(raw_name)
            if len(normalized_name.replace(" ", "")) < 2:
                self.send_json(400, {"ok": False, "message": "اكتب حرفين على الأقل من اسم الطالب."})
                return
            if len(normalized_name) > 80:
                self.send_json(400, {"ok": False, "message": "بيانات البحث أطول من المسموح."})
                return

            with DB_LOCK:
                results, has_more = search_by_name(raw_name)
            self.send_json(
                200,
                {"ok": True, "type": "name", "results": results, "hasMore": has_more},
                cache=True,
            )
        except Exception:
            self.send_json(500, {"ok": False, "message": "تعذر تنفيذ البحث الآن. حاول مرة أخرى."})

    def log_message(self, format, *args):
        return
