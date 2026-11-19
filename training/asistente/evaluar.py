"""Compara el modelo base vs base+LoRA con los MISMOS casos y criterios.

Criterios por caso:
  - json_valido: la respuesta pasa backend/asistente.validar_accion
  - accion_correcta: misma "accion" que la esperada
  - items_correctos: mismos productos y cantidades (sin importar orden)
  - exacto: accion + items + venta_id + metodo_pago coinciden

Uso:
    python evaluar.py --casos data/test_reservado.jsonl \
        --base-url http://DGX:8001 --modelo-base <id_base> --modelo-lora <id_lora>

Resultados en logs/eval_asistente_<fecha>.json. No se reportan cifras que no
salgan de este script.
"""
import argparse
import json
import sys
import time
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(RAIZ / "backend"))
import asistente  # noqa: E402


def norm_items(items):
    return sorted((i["producto"], i["cantidad"]) for i in items or [])


def evaluar_modelo(casos, catalogo, base_url, modelo):
    filas = []
    for c in casos:
        esp = c["salida"]
        fila = {"entrada": c["entrada"], "esperado": esp}
        try:
            r = asistente.interpretar(c["entrada"], catalogo, base_url=base_url, modelo=modelo)
            fila.update(obtenido=r, json_valido=True,
                        accion_correcta=r["accion"] == esp["accion"],
                        items_correctos=norm_items(r["items"]) == norm_items(esp["items"]))
            fila["exacto"] = (fila["accion_correcta"] and fila["items_correctos"]
                              and r["venta_id"] == esp["venta_id"]
                              and r["metodo_pago"] == esp["metodo_pago"])
        except Exception as e:  # noqa: BLE001
            fila.update(obtenido=None, error=str(e), json_valido=False,
                        accion_correcta=False, items_correctos=False, exacto=False)
        filas.append(fila)
    n = len(filas) or 1
    resumen = {k: sum(f[k] for f in filas) / n
               for k in ("json_valido", "accion_correcta", "items_correctos", "exacto")}
    return {"modelo": modelo, "n": len(filas), "resumen": resumen, "casos": filas}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--casos", type=Path, required=True)
    ap.add_argument("--base-url", required=True)
    ap.add_argument("--modelo-base", required=True)
    ap.add_argument("--modelo-lora", required=True)
    ap.add_argument("--catalogo", type=Path, default=RAIZ / "backend" / "catalogo.json")
    a = ap.parse_args()

    casos = [json.loads(l) for l in a.casos.read_text(encoding="utf-8").splitlines() if l.strip()]
    catalogo = json.loads(a.catalogo.read_text(encoding="utf-8"))["productos"]
    salida = {"fecha": time.strftime("%Y-%m-%d %H:%M:%S"), "casos": str(a.casos),
              "temperatura": asistente.TEMPERATURA,
              "base": evaluar_modelo(casos, catalogo, a.base_url, a.modelo_base),
              "lora": evaluar_modelo(casos, catalogo, a.base_url, a.modelo_lora)}
    destino = RAIZ / "logs" / f"eval_asistente_{time.strftime('%Y%m%d_%H%M%S')}.json"
    destino.write_text(json.dumps(salida, indent=2, ensure_ascii=False))
    print(json.dumps({"base": salida["base"]["resumen"], "lora": salida["lora"]["resumen"]}, indent=2))
    print(f"Detalle en {destino}")


if __name__ == "__main__":
    main()
