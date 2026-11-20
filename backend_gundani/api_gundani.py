import json
import sqlite3
import time
import uuid
from datetime import datetime
from typing import Optional

import requests
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

LLM_URL = "http://127.0.0.1:8081/v1/chat/completions"
DB_PATH = "gundani.db"

SYSTEM_PROMPT = (
    "Eres Gundani, asistente virtual para tienditas de abarrotes en México. "
    "Ayudas al comerciante a cobrar por QR, registrar gastos, consultar su caja y entender la economía digital en lenguaje sencillo.\n"
    "Responde SIEMPRE únicamente con un objeto JSON válido (sin texto adicional ni bloques markdown) con estas claves exactas:\n"
    '{"intencion": "...", "requiere_confirmacion": true/false, '
    '"datos": {"concepto": string|null, "cantidad": number|null, "monto": number|null, "metodo_pago": "qr"|"efectivo"|"transferencia"|null}, '
    '"respuesta_voz": "..."}\n'
    'Valores válidos de "intencion": "crear_cobro", "registrar_gasto", "consultar_resumen", "orientacion_digital", "pedir_dato", "fuera_de_alcance".\n'
    "Reglas:\n"
    "1. Para crear_cobro y registrar_gasto, requiere_confirmacion debe ser true.\n"
    "2. Si falta el monto o el concepto en un cobro o gasto, usa pedir_dato.\n"
    "3. Si recibes [CONTEXTO_CAJA], usa únicamente esos datos exactos sin inventar cifras.\n"
    "4. En dudas fiscales o de la Ley de Economía Digital, aclara que es orientación informativa y no asesoría fiscal oficial.\n"
    "5. Si piden algo ajeno a la tienda o economía digital, usa fuera_de_alcance."
)

http_session = requests.Session()

def get_conn():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn

def init_db():
    conn = get_conn()
    cur = conn.cursor()
    cur.execute("""
        CREATE TABLE IF NOT EXISTS movimientos (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            tipo TEXT NOT NULL,
            concepto TEXT NOT NULL,
            cantidad REAL DEFAULT 1,
            monto REAL NOT NULL,
            metodo_pago TEXT NOT NULL,
            origen TEXT DEFAULT 'voz',
            fecha TEXT NOT NULL
        )
    """)
    cur.execute("""
        CREATE TABLE IF NOT EXISTS billeteras_demo (
            usuario_id TEXT PRIMARY KEY,
            nombre TEXT NOT NULL,
            saldo REAL NOT NULL
        )
    """)
    cur.execute("INSERT OR IGNORE INTO billeteras_demo VALUES ('cliente_demo', 'Cliente Demo', 200.0)")
    cur.execute("INSERT OR IGNORE INTO billeteras_demo VALUES ('tienda_gundani', 'Tiendita Gundani', 500.0)")
    conn.commit()
    conn.close()

def obtener_resumen_hoy():
    hoy = datetime.now().strftime("%Y-%m-%d")
    conn = get_conn()
    cur = conn.cursor()
    cur.execute(
        "SELECT tipo, metodo_pago, SUM(monto) as total FROM movimientos WHERE fecha LIKE ? GROUP BY tipo, metodo_pago",
        (f"{hoy}%",),
    )
    rows = cur.fetchall()
    conn.close()

    ventas_qr = ventas_efectivo = ventas_transferencia = gastos = 0.0
    for r in rows:
        total = float(r["total"] or 0.0)
        if r["tipo"] == "venta":
            if r["metodo_pago"] == "qr":
                ventas_qr += total
            elif r["metodo_pago"] == "efectivo":
                ventas_efectivo += total
            elif r["metodo_pago"] == "transferencia":
                ventas_transferencia += total
        elif r["tipo"] == "gasto":
            gastos += total

    total_ventas = ventas_qr + ventas_efectivo + ventas_transferencia
    balance = total_ventas - gastos
    return {
        "fecha": hoy,
        "ventas_qr": round(ventas_qr, 2),
        "ventas_efectivo": round(ventas_efectivo, 2),
        "ventas_transferencia": round(ventas_transferencia, 2),
        "total_ventas": round(total_ventas, 2),
        "gastos": round(gastos, 2),
        "balance": round(balance, 2),
    }

app = FastAPI(title="Gundani API - Asistente y Caja Digital", version="1.1.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
init_db()

class AsistenteRequest(BaseModel):
    texto: str
    contexto_caja: Optional[dict] = None

class MovimientoConfirmarRequest(BaseModel):
    tipo: str
    concepto: str
    cantidad: Optional[float] = 1
    monto: float
    metodo_pago: str = "qr"
    origen: str = "voz"

class CobroQRRequest(BaseModel):
    cliente_id: str = "cliente_demo"
    concepto: str
    monto: float
    qr_expirado: bool = False

PALABRAS_CAJA = [
    "vendí", "vendi", "ventas", "venta de hoy", "llevo", "cierre", "caja",
    "balance", "resumen", "gané", "gane", "ganancia", "perdí", "perdi",
    "gasté", "gaste", "gastos", "mis números", "mis numeros", "libre hoy",
    "qr contra efectivo", "entró", "entro", "cobré", "cobre", "cuánto hay",
    "cuanto hay", "cómo vamos", "como vamos", "reporte", "corte",
]

def necesita_contexto_caja(texto: str) -> bool:
    t = texto.lower()
    return any(p in t for p in PALABRAS_CAJA)

@app.get("/health")
def health():
    return {
        "status": "ok",
        "modelo": "Qwen2.5-3B-Instruct + Gundani LoRA (GGUF Q4_K_M)",
        "motor": "llama-server nativo (AVX2/FMA, CPU 8 threads)",
    }

@app.post("/api/asistente")
def consultar_asistente(req: AsistenteRequest):
    texto_limpio = req.texto.strip()
    if not texto_limpio:
        raise HTTPException(status_code=400, detail="El texto no puede estar vacío.")

    user_content = texto_limpio
    resumen_usado = None

    if necesita_contexto_caja(texto_limpio):
        resumen_usado = req.contexto_caja or obtener_resumen_hoy()
        contexto = (
            f"[CONTEXTO_CAJA: ventas_qr={resumen_usado['ventas_qr']}, "
            f"ventas_efectivo={resumen_usado['ventas_efectivo']}, "
            f"ventas_transferencia={resumen_usado['ventas_transferencia']}, "
            f"gastos={resumen_usado['gastos']}, balance={resumen_usado['balance']}]"
        )
        user_content = f"{contexto}\n{texto_limpio}"

    t0 = time.time()
    try:
        resp = http_session.post(
            LLM_URL,
            json={
                "messages": [
                    {"role": "system", "content": SYSTEM_PROMPT},
                    {"role": "user", "content": user_content},
                ],
                "max_tokens": 220,
                "temperature": 0.0,
                "cache_prompt": True,
            },
            timeout=60,
        )
        resp.raise_for_status()
        raw_text = resp.json()["choices"][0]["message"]["content"].strip()
    except requests.RequestException as e:
        raise HTTPException(status_code=503, detail=f"Motor LLM no disponible: {e}")

    latencia = round(time.time() - t0, 3)
    print(f"[ASISTENTE] IN={texto_limpio!r} | CAJA={resumen_usado is not None} | {latencia}s | OUT={raw_text}", flush=True)

    try:
        parsed = json.loads(raw_text)
        if resumen_usado is not None and parsed.get("intencion") == "consultar_resumen":
            parsed["respuesta_voz"] = (
                f"Hoy llevas ${resumen_usado['total_ventas']:.0f} pesos en ventas: "
                f"${resumen_usado['ventas_qr']:.0f} por QR, "
                f"${resumen_usado['ventas_efectivo']:.0f} en efectivo y "
                f"${resumen_usado['ventas_transferencia']:.0f} por transferencia. "
                f"Tienes ${resumen_usado['gastos']:.0f} en gastos y tu balance es de "
                f"${resumen_usado['balance']:.0f} pesos."
            )
        return {
            "ok": True,
            "latencia_seg": latencia,
            "contexto_caja": resumen_usado,
            "resultado": parsed,
        }
    except json.JSONDecodeError:
        return {
            "ok": False,
            "latencia_seg": latencia,
            "error": "No se pudo interpretar la respuesta estructurada del asistente.",
            "resultado": {
                "intencion": "pedir_dato",
                "requiere_confirmacion": False,
                "datos": {"concepto": None, "cantidad": None, "monto": None, "metodo_pago": None},
                "respuesta_voz": "No logré entender bien tu solicitud. ¿Podrías repetirla indicando el producto y el monto?",
            },
            "salida_cruda": raw_text,
        }

@app.post("/api/movimientos/confirmar")
def confirmar_movimiento(mov: MovimientoConfirmarRequest):
    if mov.tipo not in ("venta", "gasto"):
        raise HTTPException(status_code=400, detail="El tipo debe ser 'venta' o 'gasto'.")
    if mov.monto <= 0:
        raise HTTPException(status_code=400, detail="El monto debe ser mayor a cero.")

    fecha_iso = datetime.now().isoformat(timespec="seconds")
    conn = get_conn()
    cur = conn.cursor()
    cur.execute(
        "INSERT INTO movimientos (tipo, concepto, cantidad, monto, metodo_pago, origen, fecha) VALUES (?, ?, ?, ?, ?, ?, ?)",
        (mov.tipo, mov.concepto, mov.cantidad or 1, mov.monto, mov.metodo_pago, mov.origen, fecha_iso),
    )
    mov_id = cur.lastrowid
    conn.commit()
    conn.close()

    return {
        "ok": True,
        "id": mov_id,
        "mensaje": f"Movimiento guardado ({mov.tipo}: ${mov.monto} por {mov.concepto}).",
        "resumen_hoy": obtener_resumen_hoy(),
    }

@app.get("/api/caja/resumen")
def get_resumen_caja():
    conn = get_conn()
    cur = conn.cursor()
    cur.execute("SELECT * FROM movimientos ORDER BY id DESC LIMIT 20")
    ultimos = [dict(r) for r in cur.fetchall()]
    cur.execute("SELECT * FROM billeteras_demo")
    billeteras = [dict(r) for r in cur.fetchall()]
    conn.close()
    return {
        "resumen_hoy": obtener_resumen_hoy(),
        "ultimos_movimientos": ultimos,
        "billeteras_demo_simuladas": billeteras,
    }

@app.post("/api/qr/cobrar")
def cobrar_qr_simulado(req: CobroQRRequest):
    if req.monto <= 0:
        return {"ok": False, "estado": "rechazado", "motivo": "monto_invalido", "mensaje_voz": "El monto del cobro debe ser mayor a cero."}
    if req.qr_expirado:
        return {"ok": False, "estado": "rechazado", "motivo": "qr_expirado", "mensaje_voz": "El código QR expiró. Genera uno nuevo para intentar de nuevo."}

    conn = get_conn()
    cur = conn.cursor()
    cur.execute("SELECT saldo FROM billeteras_demo WHERE usuario_id = ?", (req.cliente_id,))
    row = cur.fetchone()
    if not row:
        conn.close()
        return {"ok": False, "estado": "rechazado", "motivo": "cuenta_no_encontrada", "mensaje_voz": "No se encontró la cuenta del cliente."}

    saldo_actual = float(row["saldo"])
    if saldo_actual < req.monto:
        conn.close()
        return {
            "ok": False,
            "estado": "rechazado",
            "motivo": "saldo_insuficiente",
            "saldo_disponible": saldo_actual,
            "mensaje_voz": f"Pago rechazado por saldo insuficiente. El cliente solo cuenta con {saldo_actual:.0f} pesos.",
        }

    fecha_iso = datetime.now().isoformat(timespec="seconds")
    folio = f"GUND-{uuid.uuid4().hex[:8].upper()}"
    cur.execute("UPDATE billeteras_demo SET saldo = saldo - ? WHERE usuario_id = ?", (req.monto, req.cliente_id))
    cur.execute("UPDATE billeteras_demo SET saldo = saldo + ? WHERE usuario_id = 'tienda_gundani'", (req.monto,))
    cur.execute(
        "INSERT INTO movimientos (tipo, concepto, cantidad, monto, metodo_pago, origen, fecha) VALUES ('venta', ?, 1, ?, 'qr', 'qr_simulado', ?)",
        (req.concepto, req.monto, fecha_iso),
    )
    conn.commit()
    conn.close()

    return {
        "ok": True,
        "entorno": "SIMULADO_SIN_DINERO_REAL",
        "estado": "aprobado",
        "folio": folio,
        "monto": req.monto,
        "concepto": req.concepto,
        "mensaje_voz": f"Pago recibido por {req.monto:.0f} pesos por {req.concepto}.",
    }
