#!/usr/bin/env python3
"""Escribe assets/data/puntos_recarga.json desde el mapa de puntos del AMB.

La fuente (D21) es el mapa «PUNTOS PARA RECARGAS SIBUS» que enlaza la web
oficial de SIBUS (https://sibusoficial.ambq.gov.co/, «Recarga tu tarjeta
facilito»). Sus coordenadas son las de la hoja del AMB (campos LATITUD y
LONGITUD de cada punto), no una búsqueda en Google. Se baja el KML así:

    curl -L -o sibus.kml \\
      'https://www.google.com/maps/d/kml?mid=1Uh7X3YhclRBexu10addpCqpFzCtljak&forcekml=1'

y se convierte con

    python3 -I tool/puntos_recarga_desde_kml.py sibus.kml --fecha AAAA-MM-DD \\
      > assets/data/puntos_recarga.json

`--fecha` es el día de la consulta: el KML no trae fecha propia y la ficha
la enseña. Los puntos fuera del área de la app (los límites de la cámara,
`MapConstants.area*`) no entran y se cuentan por stderr. Solo biblioteca
estándar.
"""

import argparse
import json
import re
import sys
import xml.etree.ElementTree as ET

KML = {"k": "http://www.opengis.net/kml/2.2"}

# Los límites de la cámara del pasajero (map_constants.dart): un punto más
# allá no se puede ver ni tocar.
SUR, NORTE, OESTE, ESTE = 10.790, 11.164, -75.0035, -74.6251

# Lo que la hoja del AMB pone en MUNICIPIOS y es un municipio de verdad. El
# resto son barrios o sectores (HIPODROMO, Van #1-3) y se omiten.
MUNICIPIOS = {
    "BARRANQUILLA": "Barranquilla",
    "SOLEDAD": "Soledad",
    "MALAMBO": "Malambo",
    "GALAPA": "Galapa",
    "PUERTO COLOMBIA": "Puerto Colombia",
}


def limpio(texto):
    return re.sub(r"\s+", " ", texto or "").strip()


def coordenadas(datos):
    """Latitud y longitud de la hoja; seis puntos traen las dos en LATITUD."""
    lat, lon = limpio(datos.get("LATITUD")), limpio(datos.get("LONGITUD"))
    if not lon:
        partes = re.split(r"[\s,]+", lat)
        if len(partes) != 2:
            return None
        lat, lon = partes
    try:
        return float(lat), float(lon)
    except ValueError:
        return None


def main():
    argumentos = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    argumentos.add_argument("kml")
    argumentos.add_argument("--fecha", required=True, help="AAAA-MM-DD")
    a = argumentos.parse_args()
    if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", a.fecha):
        sys.exit("--fecha va como AAAA-MM-DD")

    puntos, fuera, sin_coordenadas = [], [], []
    for marca in ET.parse(a.kml).getroot().iterfind(".//k:Placemark", KML):
        datos = {
            d.get("name"): (d.findtext("k:value", default="", namespaces=KML))
            for d in marca.iterfind(".//k:Data", KML)
        }
        nombre = limpio(marca.findtext("k:name", default="", namespaces=KML))
        pv = limpio(datos.get("PV"))
        pv = pv[:-2] if pv.endswith(".0") else pv
        lugar = coordenadas(datos)
        if lugar is None:
            sin_coordenadas.append(nombre)
            continue
        lat, lon = lugar
        if not (SUR <= lat <= NORTE and OESTE <= lon <= ESTE):
            fuera.append(f"{nombre} ({lat}, {lon})")
            continue
        punto = {
            "id": f"pv-{pv}",
            "nombre": nombre,
            # Seis decimales: 0,1 m, mucho más fino que lo que cabe en un dedo.
            "lat": round(lat, 6),
            "lon": round(lon, 6),
            "direccion": limpio(datos.get("DIRECCIÓN")),
            "fuente": "sibus",
        }
        municipio = MUNICIPIOS.get(limpio(datos.get("MUNICIPIOS")).upper())
        if municipio:
            punto["municipio"] = municipio
        puntos.append(punto)

    for nombre in fuera:
        print(f"fuera del área de la app: {nombre}", file=sys.stderr)
    for nombre in sin_coordenadas:
        print(f"sin coordenadas: {nombre}", file=sys.stderr)
    print(f"{len(puntos)} puntos", file=sys.stderr)

    puntos.sort(key=lambda p: p["id"])
    json.dump(
        {
            "version": 1,
            "fuentes": {
                "sibus": {
                    "nombre": "SIBUS, Área Metropolitana de Barranquilla",
                    "url": "https://sibusoficial.ambq.gov.co/",
                    "fecha": a.fecha,
                }
            },
            "puntos": puntos,
        },
        sys.stdout,
        ensure_ascii=False,
        separators=(",", ":"),
    )
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
