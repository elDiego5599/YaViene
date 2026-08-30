# Fuente del icono de la app

`app_icon.svg` es el original del icono. No va en `assets/`: no se usa en
tiempo de ejecución, solo para regenerar los PNG del catálogo de iOS.

El logo de dentro de la app (`assets/icon/ya_viene_logo.svg`) es circular y
con fondo transparente. Un icono de iOS tiene que ser cuadrado y opaco —con
transparencia, las esquinas salen negras—, así que este archivo pone el
verde de marca a sangre y recentra el dibujo sobre su propio alto.

Para regenerarlo:

```bash
rsvg-convert -w 1024 -h 1024 -b '#00A859' tool/app_icon.svg -o /tmp/icon-1024.png
python3 tool/gen_app_icon.py /tmp/icon-1024.png
```
