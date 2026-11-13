#!/usr/bin/env python3
"""Pasarela de pago de mentira para la recarga SIBUS (D23, D8).

Hace de página de pago del operador, solo para desarrollo y demo:
  POST /recargas             {"referencia": "..."}  -> 201, queda pendiente
  GET  /recargas/<ref>       -> {"estado": "pendiente|aprobada|rechazada"}
  GET  /pagar/<ref>          -> página con «Aprobar» y «Rechazar»
  GET  /resolver/<ref>?estado=aprobada|rechazada
                             -> fija el estado y devuelve a la app por
                                yaviene://recarga?referencia=...&estado=...
Nunca recibe ni guarda el número de la tarjeta. Uso: python3 tool/pasarela_simulada.py [puerto]
"""
import json
import re
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

REF = re.compile(r"^[A-Za-z0-9_-]{16,64}$")
ESTADOS = {}
VALOR = 20000


class Pasarela(BaseHTTPRequestHandler):
    def _enviar(self, codigo, cuerpo=b"", tipo="application/json", extra=None):
        self.send_response(codigo)
        self.send_header("Content-Type", tipo)
        self.send_header("Content-Length", str(len(cuerpo)))
        for k, v in (extra or {}).items():
            self.send_header(k, v)
        self.end_headers()
        self.wfile.write(cuerpo)

    def _json(self, codigo, datos):
        self._enviar(codigo, json.dumps(datos).encode())

    def do_POST(self):
        if urlparse(self.path).path != "/recargas":
            return self._json(404, {})
        largo = min(int(self.headers.get("Content-Length") or 0), 1024)
        try:
            ref = json.loads(self.rfile.read(largo)).get("referencia", "")
        except ValueError:
            return self._json(400, {})
        if not isinstance(ref, str) or not REF.match(ref):
            return self._json(400, {})
        ESTADOS.setdefault(ref, "pendiente")
        self._json(201, {"estado": "pendiente"})

    def do_GET(self):
        url = urlparse(self.path)
        partes = url.path.strip("/").split("/")
        if len(partes) != 2 or not REF.match(partes[1]) or partes[1] not in ESTADOS:
            return self._json(404, {})
        accion, ref = partes
        if accion == "recargas":
            estado = ESTADOS[ref]
            datos = {"estado": estado}
            if estado == "aprobada":
                datos["valor"] = VALOR
            return self._json(200, datos)
        if accion == "pagar":
            html = f"""<!doctype html><meta charset=utf-8>
<meta name=viewport content="width=device-width,initial-scale=1">
<body style="font-family:-apple-system,sans-serif;padding:32px;color:#17325F">
<p style="background:#FFF1C2;display:inline-block;padding:4px 12px;border-radius:12px">Simulación</p>
<h1>Pago de prueba</h1><p>Recarga de $20.000 a tu tarjeta SIBUS.</p>
<p><a href="/resolver/{ref}?estado=aprobada" style="display:block;padding:16px;background:#1E56A8;color:#fff;border-radius:14px;text-align:center;text-decoration:none">Aprobar</a></p>
<p><a href="/resolver/{ref}?estado=rechazada" style="display:block;padding:16px;background:#EEF1F6;border-radius:14px;text-align:center;text-decoration:none;color:#17325F">Rechazar</a></p>"""
            return self._enviar(200, html.encode(), "text/html; charset=utf-8")
        if accion == "resolver":
            estado = parse_qs(url.query).get("estado", [""])[0]
            if estado not in ("aprobada", "rechazada"):
                return self._json(400, {})
            ESTADOS[ref] = estado
            return self._enviar(
                302, extra={"Location": f"yaviene://recarga?referencia={ref}&estado={estado}"}
            )
        self._json(404, {})

    def log_message(self, formato, *args):
        # La referencia es un secreto de un solo uso: no va completa a la consola.
        linea = re.sub(r"([A-Za-z0-9_-]{4})[A-Za-z0-9_-]{12,}", r"\1…", formato % args)
        sys.stderr.write(linea + "\n")


if __name__ == "__main__":
    puerto = int(sys.argv[1]) if len(sys.argv) > 1 else 8099
    ThreadingHTTPServer(("127.0.0.1", puerto), Pasarela).serve_forever()
