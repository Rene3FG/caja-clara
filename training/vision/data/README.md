# Datos de visión

> Las imágenes **no** se suben a git (ver `.gitignore`). Aquí solo se documentan.

## Estructura esperada (local / DGX Spark)

```
data/
├── crudo/<sesion>/<imagen>.jpg     # una carpeta por sesión de fotos
├── etiquetas/<sesion>/<imagen>.txt # formato YOLO o COCO (TODO: decidir)
└── splits/{train,val,test}.txt     # generado por split_por_sesion.py
```

Una **sesión** = mismo día, mismo lugar, misma luz y mismo celular. Se divide por
sesión para que fotos casi idénticas no queden en train y test a la vez.

## Procedencia y licencias

| Fuente | Quién / dónde | Nº imágenes | Licencia / permiso |
|---|---|---|---|
| Fotos propias del equipo | TODO | TODO | Propias (TODO: confirmar consentimiento del negocio) |
| Dataset público (si se usa) | TODO: nombre + URL | TODO | TODO |

## Distribución por clase

> TODO: llenar con la salida real de `split_por_sesion.py --resumen`. No estimar.

| Clase | train | val | test |
|---|---|---|---|
| TODO | | | |

## Etiquetado

- Herramienta: TODO
- Quién etiquetó y cómo se revisó: TODO
