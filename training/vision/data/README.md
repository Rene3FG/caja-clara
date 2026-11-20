# Datos de visión

> Las imágenes **no** se suben a git (`.gitignore`). Viven en el servidor DLI
> (`/dli/task/caja-clara/datos/final/{train,val,test}`) y las fotos propias en el paquete de entrenamiento.

## Procedencia y licencias

| Fuente | Quién / dónde | Uso | Licencia |
|---|---|---|---|
| ProductosOXXO_V02 v3 | Roboflow Universe (autor: Ipsum) — universe.roboflow.com/ipsum/productosoxxo_v02 | train / val / test | CC BY 4.0 |
| Dataset Mercado v1 | Roboflow Universe (autor: FundamentosIA) — universe.roboflow.com/fundamentosia/dataset-mercado | train / val / test | CC BY 4.0 |
| Fotos propias p01, p02, p04 | Tomadas por el equipo con celular; sin rostros ni datos personales | train (v2, v3) | Propias |
| Fotos propias p03 (36) | Tomadas por el equipo; **reservadas**, nunca se entrenó con ellas | Evaluación realista | Propias |

## Distribución por clase (v1 — `../distribucion_datos.json`)

| Clase | train | val | test |
|---|---|---|---|
| chokis | 51 | 5 | 0 |
| coca_cola | 376 | 56 | 47 |
| doritos | 69 | 3 | 18 |
| gansito | 154 | 11 | 15 |
| panditas | 41 | 12 | 11 |
| sabritas | 60 | 11 | 6 |
| skittles | 68 | 0 | 9 |
| **Imágenes** | **819** | **97** | **106** |

v2: train = 930 imágenes / 956 objetos (+ p01, p02) — `../logs/distribucion_datos_v2.json`.
v3: + p04 — `../logs/bitacora_v3.txt`. Val y test no cambian entre versiones.

Desbalance: coca_cola domina train; chokis no tiene ejemplos en test y skittles no tiene en val
(por eso las chokis se evalúan con las fotos propias p03).

## Separación y duplicados

- `../preparar_datos.py`: las imágenes públicas se agrupan por **imagen original** (las variantes
  aumentadas de Roboflow `*_jpg.rf.*` quedan en el mismo grupo) y los grupos se reparten 80/10/10
  en train/val/test con semilla 1234. Así ninguna versión de la misma imagen queda en dos conjuntos.
- Las fotos propias se asignan **por sesión** (misma luz, lugar y celular) con `--train-sesiones`.
- Además se calcula el SHA-1 de cada imagen y se descarta cualquier duplicado exacto entre conjuntos.
  (Los archivos `../logs/hashes_v*.txt` guardan el sha256 del checkpoint y del ONNX de cada versión.)

## Etiquetado

- Públicos: etiquetas de origen (COCO), clases mapeadas a las 7 del proyecto + `otro_producto`.
- Propias: pre-etiquetadas con el detector v1 (`training/detector/preetiquetar.py`) y **revisadas y
  corregidas a mano** en Roboflow; correcciones extra en `../datos_propios/correcciones_manuales.txt`.
- Etiquetas de evaluación de p03: `../evaluacion/v1_p03/etiquetas_p03.csv`.
