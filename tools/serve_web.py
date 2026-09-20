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

І найголовніше — HTTPS.

  ЗАХИЩЕНИЙ КОНТЕКСТ. Godot для вебу вимагає secure context. Браузер уважає захищеним
  `https://` та `http://localhost`, але НЕ `http://192.168.x.x`. Тобто на самому Маку
  збірка відкривається, а з телефона та сама адреса дає «Secure Context - Check web server
  configuration (use HTTPS)» і далі не йде. Тому сервер типово підіймається під TLS із
  самопідписаним сертифікатом, у який вписано і `localhost`, і поточну адресу в мережі.

  Телефон при першому заході скаже, що з'єднання не приватне. Так і має бути: сертифікат
  нічий, його ніхто не підписував. Треба розгорнути «Подробиці» й погодитись — це локальна
  мережа й власна машина. `--http` вимикає TLS, якщо колись знадобиться.
"""
import argparse
import http.server
import os
import socket
import socketserver
import ssl
import subprocess

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


CERT_DIR = os.path.join(os.path.expanduser("~"), ".cache", "bizhy-web-cert")


def make_cert(ip):
    """Самопідписаний сертифікат на `localhost` і поточну адресу в мережі. Робимо один раз і
    кешуємо: адреса в домашньому Wi-Fi міняється рідко, а перевипуск щоразу означав би, що
    телефон щоразу питає наново. Якщо адреса змінилась — перевипускаємо."""
    os.makedirs(CERT_DIR, exist_ok=True)
    cert = os.path.join(CERT_DIR, "cert.pem")
    key = os.path.join(CERT_DIR, "key.pem")
    stamp = os.path.join(CERT_DIR, "for-ip.txt")
    have = os.path.exists(cert) and os.path.exists(key) \
        and os.path.exists(stamp) and open(stamp).read().strip() == ip
    if have:
        return cert, key
    san = "subjectAltName=DNS:localhost,IP:127.0.0.1,IP:%s" % ip
    cmd = ["openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes",
           "-keyout", key, "-out", cert, "-days", "825",
           "-subj", "/CN=bizhy-bizhy.local", "-addext", san]
    try:
        subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except (OSError, subprocess.CalledProcessError):
        return None, None
    open(stamp, "w").write(ip)
    return cert, key


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dir", default="export")
    ap.add_argument("--port", type=int, default=8060)
    ap.add_argument("--http", action="store_true",
                    help="без TLS. З телефона тоді НЕ відкриється: Godot вимагає "
                         "захищеного контексту, а http://<адреса> ним не є")
    a = ap.parse_args()

    if not os.path.isdir(a.dir):
        raise SystemExit("нема теки %s — спершу зроби експорт" % a.dir)
    page = next((f for f in sorted(os.listdir(a.dir)) if f.endswith(".html")), None)
    if page is None:
        raise SystemExit("у %s немає .html — експорт не завершився" % a.dir)

    os.chdir(a.dir)
    ip = lan_ip()
    scheme = "http"
    ctx = None
    if not a.http:
        cert, key = make_cert(ip)
        if cert is None:
            print("! openssl не спрацював — піднімаю без TLS; з телефона не відкриється",
                  flush=True)
        else:
            ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
            ctx.load_cert_chain(cert, key)
            scheme = "https"

    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.TCPServer(("0.0.0.0", a.port), Handler) as httpd:
        if ctx is not None:
            httpd.socket = ctx.wrap_socket(httpd.socket, server_side=True)
        print("тут:        %s://localhost:%d/%s" % (scheme, a.port, page), flush=True)
        print("з телефона: %s://%s:%d/%s   (той самий Wi-Fi)"
              % (scheme, ip, a.port, page), flush=True)
        if ctx is not None:
            print("Телефон скаже, що з'єднання не приватне — сертифікат самопідписаний.",
                  flush=True)
            print("Це нормально: розгорни «Подробиці» / «Advanced» і погодься.", flush=True)
        print("Ctrl+C — спинити", flush=True)
        httpd.serve_forever()


main()
