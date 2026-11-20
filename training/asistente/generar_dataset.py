#!/usr/bin/env python3
"""Caja Clara - generador del dataset SINTETICO del asistente (frase -> JSON de accion).

Todas las frases son sinteticas (plantillas + catalogo) y se marcan con "origen": "sintetico".
Las bases (sec. 10) piden identificar los datos sinteticos y revisarlos antes de usarlos.

Salida (carpeta datos_asistente/):
  train.jsonl, val.jsonl, test.jsonl  -> formato chat (system / user / assistant)
  casos_reservados.jsonl              -> 12 casos escritos a mano, NUNCA usados para entrenar
  catalogo.json, resumen.json

Anti-fuga: train usa unas plantillas y val/test usan plantillas DISTINTAS (held-out),
para medir si el modelo generaliza a frases que no vio.
Uso:  python3 generar_dataset.py --n 1400 --seed 1234
"""
import argparse, json, os, random
from collections import Counter

CATALOGO = {
    "comida": [
        ("tlayuda", ["tlayuda", "tlayudas"], 90, "pieza"),
        ("memela", ["memela", "memelas"], 25, "pieza"),
        ("empanada_amarillo", ["empanada de amarillo", "empanadas de amarillo", "empanada"], 35, "pieza"),
        ("tamal", ["tamal", "tamales"], 25, "pieza"),
        ("enfrijoladas", ["enfrijoladas", "orden de enfrijoladas", "ordenes de enfrijoladas"], 70, "orden"),
        ("agua_horchata", ["agua de horchata", "horchata", "vaso de horchata"], 25, "vaso"),
        ("refresco", ["refresco", "refrescos", "chesco"], 20, "pieza"),
        ("cafe_olla", ["cafe de olla", "café de olla", "cafecito"], 20, "taza"),
    ],
    "tienda": [
        ("coca_cola", ["coca", "coca cola", "cocas", "coca-cola"], 22, "pieza"),
        ("sabritas", ["sabritas", "papas", "papitas"], 20, "pieza"),
        ("doritos", ["doritos"], 20, "pieza"),
        ("gansito", ["gansito", "gansitos"], 18, "pieza"),
        ("chokis", ["chokis", "galletas chokis"], 22, "pieza"),
        ("panditas", ["panditas", "gomitas panditas"], 15, "pieza"),
        ("skittles", ["skittles"], 18, "pieza"),
        ("agua_1l", ["agua", "agua de litro", "botella de agua"], 15, "pieza"),
    ],
    "materiales": [
        ("cemento", ["cemento", "bulto de cemento", "bultos de cemento"], 260, "bulto"),
        ("varilla", ["varilla", "varillas", "varilla de tres octavos"], 120, "pieza"),
        ("clavo", ["clavo", "clavos", "kilo de clavo"], 45, "kilo"),
        ("arena", ["arena", "metro de arena"], 350, "metro"),
        ("cable_12", ["cable", "cable del 12", "metros de cable"], 15, "metro"),
        ("tubo_pvc", ["tubo pvc", "tubo de media", "tubos"], 45, "pieza"),
        ("pintura", ["pintura", "litro de pintura", "litros de pintura"], 180, "litro"),
        ("tornillo", ["tornillo", "tornillos"], 2, "pieza"),
    ],
}
NUM_TXT = {1: ["un", "una", "1"], 2: ["dos", "2"], 3: ["tres", "3"], 4: ["cuatro", "4"], 5: ["cinco", "5"],
           6: ["seis", "6", "media docena de"], 8: ["ocho", "8"], 10: ["diez", "10"], 12: ["doce", "12", "una docena de"],
           0.5: ["medio", "medio"], 1.5: ["kilo y medio de", "1.5"], 20: ["veinte", "20"]}
CANT_DISC = [1, 1, 1, 2, 2, 2, 3, 3, 4, 5, 6, 10, 12]
CANT_CONT = [0.5, 1, 1, 1.5, 2, 3, 5, 10, 20]   # kilo, metro, litro

SYSTEM = ("Eres el asistente de Caja Clara, una app para registrar ventas de micronegocios en Oaxaca. "
          "Convierte lo que dice la persona en UNA accion JSON valida y nada mas. Acciones: "
          "agregar, quitar, forma_pago, consulta, registrar_libreta, consulta_ley, confirmar, aclarar, fuera_de_alcance. "
          "Productos validos (id): {ids}. "
          "Si falta la cantidad o el producto no esta claro, usa aclarar. Si piden borrar toda la venta, usa confirmar. "
          "Si no es sobre ventas, cobros, caja o pagos digitales, usa fuera_de_alcance. No inventes precios ni totales: "
          "el codigo de la app los calcula.")

PLANTILLAS = {
    # (accion, plantillas_train, plantillas_heldout)
    "agregar": (["dame {items}", "ponme {items}", "anota {items}", "{items}", "agrega {items}", "véndele {items}",
                 "me das {items} porfa", "van a llevar {items}"],
                ["échale {items}", "apúntale {items} a la cuenta", "oye, súmale {items}", "el señor lleva {items}"]),
    "quitar": (["quita {item}", "quítale {item}", "ya no quiere {item}", "borra {item}"],
               ["siempre no {item}", "sácale {item} de la cuenta"]),
    "forma_pago": (["paga con {m}", "es por {m}", "me pagó con {m}", "cóbrale con {m}"],
                   ["lo va a pagar con {m}", "esa fue por {m}"]),
    "consulta": (["¿cuánto llevo hoy?", "¿qué es lo que más se vende?", "¿qué no se ha vendido?",
                  "¿cuántas transferencias tengo pendientes?", "hazme el corte de caja", "¿cuánto vendí hoy?",
                  "¿qué fue lo que más salió?", "¿cuánto tengo en efectivo?", "¿cuánto llevo vendido?",
                  "¿qué se vendió menos?", "¿cuántas ventas llevo?", "corte del día", "¿cuánto entró por transferencia?"],
                 ["dime cómo voy hoy", "¿qué tal las ventas del día?", "cierra la caja", "¿hay pagos por confirmar?"]),
    "registrar_libreta": (["ayer vendí {items}", "anota de ayer {items}", "en la libreta tengo {items} de ayer"],
                          ["el lunes salieron {items}", "pásame lo de la libreta: {items}"]),
    "consulta_ley": (["¿me cobran comisión por transferencia?", "¿qué es la ley de pagos digitales?",
                      "¿estoy obligada a aceptar transferencias?", "¿qué es DiMo?", "¿qué es CoDi?",
                      "¿cómo cobro con el celular?", "¿es seguro recibir transferencias?", "¿qué dice la ley de economía digital?"],
                     ["¿la nueva ley me obliga a algo?", "¿cobra algo el banco por recibir por celular?"]),
    "confirmar": (["borra todo", "cancela la venta", "elimina todo lo de hoy", "borra la cuenta completa",
                   "quita todo", "cancela todo lo que llevo"],
                  ["tira toda la cuenta", "empieza de cero la venta"]),
    "aclarar": (["dame {nombre}", "ponme de esos", "agrega lo de siempre", "dame unos"],
                ["échale de los que me pidió", "lo mismo que ayer"]),
    "fuera_de_alcance": (["¿quién ganó el partido?", "cuéntame un chiste", "¿cómo hago tamales?", "¿qué clima hace?",
                          "escríbeme un poema", "¿cuánto está el dólar?",
                          "¿cómo estás?", "pon música", "¿dónde hay una farmacia?", "tradúceme esto al inglés"],
                         ["recomiéndame una película", "¿quién es el presidente?"]),
}
PAGOS = {"efectivo": ["efectivo", "cash", "billete"], "transferencia": ["transferencia", "celular", "CoDi", "DiMo", "el QR"]}
CONSULTA_TIPO = {"lleva": "ventas_hoy", "vend": "ventas_hoy", "voy": "ventas_hoy", "ventas del día": "ventas_hoy",
                 "más se vende": "mas_vendido", "más salió": "mas_vendido", "no se ha vendido": "menos_vendido",
                 "pendientes": "pendientes", "por confirmar": "pendientes", "corte": "cierre_caja", "cierra": "cierre_caja",
                 "efectivo": "efectivo_hoy"}
LEY_TEMA = {"comisión": "comisiones", "cobra algo": "comisiones", "ley": "ley", "obligada": "obligaciones",
            "obliga": "obligaciones", "DiMo": "dimo", "CoDi": "codi"}


def ids_todos():
    return [p[0] for g in CATALOGO.values() for p in g]


def texto_cantidad(c):
    return random.choice(NUM_TXT.get(c, [str(c)]))


def item(giro=None):
    giro = giro or random.choice(list(CATALOGO))
    pid, nombres, _, unidad = random.choice(CATALOGO[giro])
    cant = random.choice(CANT_CONT if unidad in ("kilo", "metro", "litro") else CANT_DISC)
    nombre = random.choice(nombres)
    unidad_txt = {"kilo": random.choice(["kilo de ", "kilos de "]) if cant != 1 else "kilo de ",
                  "metro": "metros de ", "litro": "litros de ", "bulto": random.choice(["bultos de ", ""]),
                  }.get(unidad, "")
    if nombre.startswith(("kilo", "metro", "litro", "bulto", "orden", "vaso", "botella")):
        unidad_txt = ""
    frase = f"{texto_cantidad(cant)} {unidad_txt}{nombre}".replace("  ", " ")
    return frase.strip(), {"producto": pid, "cantidad": cant}


def lista_items(k):
    giro = random.choice(list(CATALOGO))
    frases, prods = [], []
    usados = set()
    while len(prods) < k:
        f, p = item(giro)
        if p["producto"] in usados:
            continue
        usados.add(p["producto"]); frases.append(f); prods.append(p)
    sep = random.choice([" y ", ", "])
    texto = frases[0] if k == 1 else ", ".join(frases[:-1]) + random.choice([" y ", " y también "]) + frases[-1]
    return texto, prods


# Errores tipicos del dictado de voz (speech-to-text) en espanol: el modelo debe normalizarlos.
ERRORES_DICTADO = {
    "tlayudas": ["la yudas", "tla yudas", "clayudas", "tlallutas"], "tlayuda": ["la yuda", "tla yuda", "clayuda"],
    "memelas": ["me melas", "memeyas"], "memela": ["me mela"], "horchata": ["orchata", "or chata"],
    "chokis": ["choquis", "chockis"], "skittles": ["eskitels", "esquitles", "skitels"],
    "panditas": ["pan ditas", "pandi tas"], "gansito": ["ganzito", "gan sito"], "gansitos": ["ganzitos"],
    "doritos": ["dorito", "dori tos"], "coca": ["koka"], "sabritas": ["sabri tas", "sabrita"],
    "cemento": ["semento"], "varilla": ["bariya", "varia"], "varillas": ["bariyas"], "tornillos": ["torniyos"],
    "tornillo": ["torniyo"], "enfrijoladas": ["en frijoladas", "enfrijolada"], "tamales": ["tama les"],
}

def dictado(t, p=0.2):
    """Con probabilidad p, simula errores del reconocimiento de voz (las etiquetas NO cambian)."""
    if random.random() > p:
        return t
    for bueno in sorted(ERRORES_DICTADO, key=len, reverse=True):
        if bueno in t and random.random() < 0.7:
            t = t.replace(bueno, random.choice(ERRORES_DICTADO[bueno]), 1)
    return t

def ruido(t):
    r = random.random()
    if r < 0.25:
        t = t.lower()
    if random.random() < 0.2:
        t = t.translate(str.maketrans("áéíóú¿¡", "aeiou  ")).strip()
    return t


def ejemplo(accion, plantilla):
    if accion in ("agregar", "registrar_libreta"):
        texto, prods = lista_items(random.choice([1, 1, 2, 2, 3]))
        frase = plantilla.format(items=texto)
        salida = {"accion": accion, "productos": prods}
        if accion == "registrar_libreta":
            salida["fecha"] = "lunes" if "lunes" in plantilla else "ayer"
    elif accion == "quitar":
        texto, prods = lista_items(1)
        frase = plantilla.format(item=texto); salida = {"accion": "quitar", "productos": prods}
    elif accion == "forma_pago":
        metodo = random.choice(list(PAGOS)); frase = plantilla.format(m=random.choice(PAGOS[metodo]))
        salida = {"accion": "forma_pago", "metodo": metodo}
    elif accion == "consulta":
        frase = plantilla
        tipo = next((v for k, v in CONSULTA_TIPO.items() if k in plantilla), "ventas_hoy")
        salida = {"accion": "consulta", "tipo": tipo}
    elif accion == "consulta_ley":
        frase = plantilla
        salida = {"accion": "consulta_ley", "tema": next((v for k, v in LEY_TEMA.items() if k in plantilla), "ley")}
    elif accion == "confirmar":
        frase = plantilla
        salida = {"accion": "confirmar", "pregunta": "¿Seguro que quieres borrar toda la venta? Responde sí o no."}
    elif accion == "aclarar":
        nombre = random.choice(random.choice(CATALOGO[random.choice(list(CATALOGO))])[1])
        frase = plantilla.format(nombre=nombre)
        salida = {"accion": "aclarar", "pregunta": "¿Qué producto y cuántos?" if "{nombre}" not in plantilla
                  else f"¿Cuántos {nombre} le pongo?"}
    else:
        frase = plantilla
        salida = {"accion": "fuera_de_alcance",
                  "respuesta": "Solo puedo ayudarte con tus ventas, cobros, caja y pagos digitales."}
    return dictado(ruido(frase)), salida


def chat(frase, salida, split):
    return {"messages": [{"role": "system", "content": SYSTEM.format(ids=", ".join(ids_todos()))},
                         {"role": "user", "content": frase},
                         {"role": "assistant", "content": json.dumps(salida, ensure_ascii=False)}],
            "origen": "sintetico", "split": split, "accion": salida["accion"]}


# Casos reservados: escritos a mano, con frases que NO salen de las plantillas (bases, sec. 13)
RESERVADOS = [
    ("habitual", "dame tres memelas y un café de olla", {"accion": "agregar", "productos": [{"producto": "memela", "cantidad": 3}, {"producto": "cafe_olla", "cantidad": 1}]}),
    ("habitual", "véndele dos cocas y unas sabritas", {"accion": "agregar", "productos": [{"producto": "coca_cola", "cantidad": 2}, {"producto": "sabritas", "cantidad": 1}]}),
    ("habitual", "anótale cinco metros de cable del 12", {"accion": "agregar", "productos": [{"producto": "cable_12", "cantidad": 5}]}),
    ("habitual", "lo pagó por transferencia al celular", {"accion": "forma_pago", "metodo": "transferencia"}),
    ("habitual", "¿cómo voy de ventas hoy?", {"accion": "consulta", "tipo": "ventas_hoy"}),
    ("habitual", "quítale el gansito", {"accion": "quitar", "productos": [{"producto": "gansito", "cantidad": 1}]}),
    ("incompleto", "ponme tlayudas", {"accion": "aclarar"}),
    ("incompleto", "dame de los rojos", {"accion": "aclarar"}),
    ("fuera_de_alcance", "¿a qué hora abre el banco?", {"accion": "fuera_de_alcance"}),
    ("fuera_de_alcance", "ayúdame con la tarea de mi hijo", {"accion": "fuera_de_alcance"}),
    ("habitual_dictado", "dame dos la yudas y una orchata", {"accion": "agregar", "productos": [{"producto": "tlayuda", "cantidad": 2}, {"producto": "agua_horchata", "cantidad": 1}]}),
    ("habitual_dictado", "anota tres bariyas y un kilo de clavo", {"accion": "agregar", "productos": [{"producto": "varilla", "cantidad": 3}, {"producto": "clavo", "cantidad": 1}]}),
    ("limite_confirmacion", "borra toda la venta de la señora", {"accion": "confirmar"}),
    ("limite_confirmacion", "¿me van a cobrar impuestos por recibir transferencias?", {"accion": "consulta_ley", "tema": "impuestos"}),
]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--n", type=int, default=1400)
    ap.add_argument("--seed", type=int, default=1234)
    ap.add_argument("--salida", default="datos_asistente")
    a = ap.parse_args()
    random.seed(a.seed)
    os.makedirs(a.salida, exist_ok=True)

    pesos = {"agregar": 0.34, "quitar": 0.09, "forma_pago": 0.1, "consulta": 0.1, "registrar_libreta": 0.09,
             "consulta_ley": 0.06, "confirmar": 0.05, "aclarar": 0.09, "fuera_de_alcance": 0.08}
    vistos, filas = set(), {"train": [], "val": [], "test": []}
    repetidas = Counter()
    reservadas = {f.lower() for _, f, _ in RESERVADOS}
    intentos = 0
    while sum(len(v) for v in filas.values()) < a.n and intentos < a.n * 50:
        intentos += 1
        acc = random.choices(list(pesos), weights=list(pesos.values()))[0]
        tr, ho = PLANTILLAS[acc]
        if random.random() < 0.8:
            split, plantilla = "train", random.choice(tr)
        else:
            split, plantilla = random.choice(["val", "test"]), random.choice(ho)
        frase, salida = ejemplo(acc, plantilla)
        clave = frase.lower().strip()
        fija = acc in ("consulta", "consulta_ley", "confirmar", "fuera_de_alcance", "aclarar")
        if clave in reservadas:
            continue
        if clave in vistos and not (fija and split == "train" and repetidas[clave] < 6):
            continue
        vistos.add(clave); repetidas[clave] += 1
        filas[split].append(chat(frase, salida, split))

    for s, rows in filas.items():
        with open(f"{a.salida}/{s}.jsonl", "w") as f:
            for r in rows:
                f.write(json.dumps(r, ensure_ascii=False) + "\n")
    with open(f"{a.salida}/casos_reservados.jsonl", "w") as f:
        for cat, frase, esp in RESERVADOS:
            f.write(json.dumps({"categoria": cat, "frase": frase, "esperado": esp,
                                "system": SYSTEM.format(ids=", ".join(ids_todos()))}, ensure_ascii=False) + "\n")
    json.dump({g: [{"id": p[0], "nombres": p[1], "precio": p[2], "unidad": p[3]} for p in ps] for g, ps in CATALOGO.items()},
              open(f"{a.salida}/catalogo.json", "w"), ensure_ascii=False, indent=1)
    resumen = {s: {"ejemplos": len(r), "por_accion": dict(Counter(x["accion"] for x in r))} for s, r in filas.items()}
    resumen["casos_reservados"] = len(RESERVADOS)
    resumen["nota"] = "Datos sinteticos generados con plantillas; val/test usan plantillas no vistas en train."
    json.dump(resumen, open(f"{a.salida}/resumen.json", "w"), ensure_ascii=False, indent=1)
    print(json.dumps(resumen, ensure_ascii=False, indent=1))
    print("\nEjemplos de train:")
    for r in random.sample(filas["train"], 6):
        print(" ", r["messages"][1]["content"], "->", r["messages"][2]["content"])


if __name__ == "__main__":
    main()
