#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""serve_web.py — віддати веб-збірку так, щоб вона справді відкрилась.

    python3 tools/serve_web.py            # тека export/, порт 8060
    python3 tools/serve_web.py --port 9000 --dir export

Друкує адресу для цього комп'ютера І адресу в локальній мережі — щоб відкрити з телефона,
який у тому самому Wi-Fi. Це і є сенс вправи: гра мобільна, дивитись її треба на телефоні.

Чому не `python3 -m http.server`. Три причини, кожна ламає збірку по-своєму:

  ТИП ФАЙЛУ. Вбудований сервер не знає ні `.wasm`, ні `.pck` і віддає їх як
  application/octet-stream. Браузер тоді відмовляється від `WebAssembly.instantiateStreaming`,
  і запуск або падає, або мовчки їде довгим шляхом.

  ЗАГОЛОВКИ ІЗОЛЯЦІЇ. Godot із підтримкою потоків вимагає SharedArrayBuffer, а той — пари
  Cross-Origin-Opener-Policy / Cross-Origin-Embedder-Policy. Наша збірка зроблена БЕЗ потоків
  (`variant/thread_support=false`), тож могла б і без них, але заголовки нічого не ламають, а
  збірку з потоками врятують.

  КЕШ. Між двома експортами файли називаються однаково. Без заборони кешувати телефон
  показує вчорашню збірку, і півгодини йде на пошук вади, якої вже немає.
"""
import argparse
import http.server
import os
import socket
import socketserver

TYPES = {
    ".wasm": "application/wasm",
    ".pck": "application/octet-stream",
    ".js": "text/javascript",
    ".html": "text/html; charset=utf-8",
    ".json": "application/json",
    ".png": "image/png",
    ".svg": "image/svg+xml",
    ".worklet.js": "text/javascript",
}


class Handler(http.server.SimpleHTTPRequestHandler):
    def guess_type(self, path):
        for ext, mime in TYPES.items():
            if path.endswith(ext):
                return mime
        return super().guess_type(path)

    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def log_message(self, fmt, *args):
        # без шуму по кожному файлу: цікаві лише помилки
        if not str(args[1] if len(args) > 1 else "").startswith("2"):
            super().log_message(fmt, *args)


def lan_ip():
    """Адреса цього комп'ютера в локальній мережі. Сокет нікуди не йде — це лише спосіб
    спитати систему, який інтерфейс вона обрала б для виходу назовні."""
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(("10.255.255.255", 1))
        return s.getsockname()[0]
    except OSError:
        return "127.0.0.1"
    finally:
        s.close()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dir", default="export")
    ap.add_argument("--port", type=int, default=8060)
    a = ap.parse_args()

    if not os.path.isdir(a.dir):
        raise SystemExit("нема теки %s — спершу зроби експорт" % a.dir)
    page = next((f for f in sorted(os.listdir(a.dir)) if f.endswith(".html")), None)
    if page is None:
        raise SystemExit("у %s немає .html — експорт не завершився" % a.dir)

    os.chdir(a.dir)
    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.TCPServer(("0.0.0.0", a.port), Handler) as httpd:
        print("тут:       http://localhost:%d/%s" % (a.port, page), flush=True)
        print("з телефона: http://%s:%d/%s   (той самий Wi-Fi)"
              % (lan_ip(), a.port, page), flush=True)
        print("Ctrl+C — спинити", flush=True)
        httpd.serve_forever()


main()
