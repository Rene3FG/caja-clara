"""Genera frases SINTÉTICAS -> JSON de acciones para el ajuste LoRA.

Cada ejemplo lleva "sintetico": true. Se dividen en train/val/test y se
reservan 10 casos (test_reservado.jsonl) que no se usan ni para entrenar ni
para ajustar hiperparámetros: solo para la evaluación final base vs LoRA.

Uso:
    python generar_dataset.py --catalogo ../../backend/catalogo.json \
        --salida data --n 1500 --semilla 42
"""
import argparse
import json
import random
from pathlib import Path

# TODO: ampliar plantillas con frases reales (anonimizadas) de las pruebas de uso,
# marcándolas como "sintetico": false y documentándolo en data/README.md.
PLANTILLAS_VENTA = [
    "vendí {c} {p}",
    "anota {c} {p}",
    "me compraron {c} {p} en {m}",
    "cobra {c} {p} y {c2} {p2}",
    "registra {c} de {p}, pagó con {m}",
]
PLANTILLAS_CORREGIR = [
    "en la venta {v} eran {c} {p}, no {c2}",
    "corrige la venta {v}: {c} {p}",
]
PLANTILLAS_CONSULTA = ["¿cuánto vendí hoy?", "¿cuántas ventas llevo?", "¿qué se vendió más?"]
PLANTILLAS_EXPLICAR = ["¿por qué salió pendiente el pago?", "¿qué significa que falló la transferencia?"]
NUMEROS = {1: "un", 2: "dos", 3: "tres", 4: "cuatro", 5: "cinco"}
METODOS = {"efectivo": "efectivo", "transferencia": "transferencia"}


def cantidad(rng):
    n = rng.randint(1, 5)
    return n, rng.choice([str(n), NUMEROS[n]])


def ejemplo(rng, nombres):
    tipo = rng.choices(["venta", "corregir", "consulta", "explicar"], [6, 2, 1, 1])[0]
    if tipo == "venta":
        t = rng.choice(PLANTILLAS_VENTA)
        (n1, c1), (n2, c2) = cantidad(rng), cantidad(rng)
        p1, p2 = rng.sample(nombres, 2) if len(nombres) > 1 else (nombres[0], nombres[0])
        m = rng.choice(list(METODOS))
        items = [{"producto": p1, "cantidad": n1}]
        if "{p2}" in t:
            items.append({"producto": p2, "cantidad": n2})
        texto = t.format(c=c1, p=p1, c2=c2, p2=p2, m=m)
        salida = {"accion": "registrar_venta", "items": items, "venta_id": None,
                  "metodo_pago": m if "{m}" in t else None,
                  "explicacion": "Registro la venta; confírmala en pantalla."}
    elif tipo == "corregir":
        t = rng.choice(PLANTILLAS_CORREGIR)
        (n1, c1), (_, c2) = cantidad(rng), cantidad(rng)
        p, v = rng.choice(nombres), rng.randint(1, 200)
        texto = t.format(v=v, c=c1, p=p, c2=c2)
        salida = {"accion": "corregir_venta", "items": [{"producto": p, "cantidad": n1}],
                  "venta_id": v, "metodo_pago": None,
                  "explicacion": f"Corrijo la venta {v}; confírmalo en pantalla."}
    elif tipo == "consulta":
        texto = rng.choice(PLANTILLAS_CONSULTA)
        salida = {"accion": "consultar", "items": [], "venta_id": None, "metodo_pago": None,
                  "explicacion": "Consulto tus ventas."}
    else:
        texto = rng.choice(PLANTILLAS_EXPLICAR)
        salida = {"accion": "explicar", "items": [], "venta_id": None, "metodo_pago": None,
                  "explicacion": "TODO: explicación basada en el estado del pago (simulado)."}
    return {"entrada": texto, "salida": salida, "sintetico": True}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--catalogo", type=Path, default=Path("../../backend/catalogo.json"))
    ap.add_argument("--salida", type=Path, default=Path("data"))
    ap.add_argument("--n", type=int, default=1500)
    ap.add_argument("--semilla", type=int, default=42)
    a = ap.parse_args()

    rng = random.Random(a.semilla)
    nombres = [p["nombre"] for p in json.loads(a.catalogo.read_text(encoding="utf-8"))["productos"]]
    vistos, ejemplos = set(), []
    intentos = 0
    while len(ejemplos) < a.n and intentos < a.n * 20:
        intentos += 1
        e = ejemplo(rng, nombres)
        if e["entrada"] in vistos:
            continue
        vistos.add(e["entrada"])
        ejemplos.append(e)

    rng.shuffle(ejemplos)
    reservados, resto = ejemplos[:10], ejemplos[10:]
    n_test, n_val = int(len(resto) * 0.1), int(len(resto) * 0.1)
    partes = {"test_reservado": reservados, "test": resto[:n_test],
              "val": resto[n_test:n_test + n_val], "train": resto[n_test + n_val:]}

    a.salida.mkdir(parents=True, exist_ok=True)
    for nombre, filas in partes.items():
        with open(a.salida / f"{nombre}.jsonl", "w", encoding="utf-8") as f:
            for fila in filas:
                f.write(json.dumps(fila, ensure_ascii=False) + "\n")
        print(f"{nombre}: {len(filas)}")


if __name__ == "__main__":
    main()
