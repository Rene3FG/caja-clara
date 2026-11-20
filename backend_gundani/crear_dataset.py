import json
import os
import random

random.seed(42)
os.makedirs("data", exist_ok=True)

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

def make_entry(user_text, intencion, req_conf, concepto, cantidad, monto, metodo, resp_voz, categoria="general"):
    assistant_obj = {
        "intencion": intencion,
        "requiere_confirmacion": req_conf,
        "datos": {
            "concepto": concepto,
            "cantidad": cantidad,
            "monto": monto,
            "metodo_pago": metodo,
        },
        "respuesta_voz": resp_voz,
    }
    return {
        "categoria": categoria,
        "messages": [
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": user_text},
            {"role": "assistant", "content": json.dumps(assistant_obj, ensure_ascii=False)},
        ],
    }

# ==============================================================================
# 1. CONJUNTO DE ENTRENAMIENTO (TRAIN)
# ==============================================================================
train_data = []

# A) Cobros habituales (con modismos mexicanos y errores típicos de dictado STT)
cobros_train = [
    ("Cóbrale 45 pesos por dos cocas de 600", "Coca-Cola 600ml", 2, 45, "qr"),
    ("Cobra 38 varos de un litro de leche y un pan", "Leche y pan", 1, 38, "qr"),
    ("Genera un QR de 65 pesos por medio kilo de huevo y tortillas", "Huevo y tortillas", 1, 65, "qr"),
    ("Cóbrale 120 baros por un garrafón y dos sabritas", "Garrafón y Sabritas", 1, 120, "qr"),
    ("Anota venta de 25 pesos de unas papitas en efectivo", "Papitas", 1, 25, "efectivo"),
    ("Me van a pagar 82 pesos con QR por aceite y arroz", "Aceite y arroz", 1, 82, "qr"),
    ("Cobra 50 varos de una recarga Telcel", "Recarga Telcel", 1, 50, "qr"),
    ("Cóbrale 19 pesos por un bolillo y un jugo", "Bolillo y jugo", 1, 19, "qr"),
    ("Hazme el cobro de 140 pesos por dos kilos de azúcar y café", "Azúcar y café", 1, 140, "qr"),
    ("Venta de 32 pesos por dos chescos en QR", "Refrescos", 2, 32, "qr"),
    ("Cóbrale al cliente 74 pesos de jamón y queso Oaxaca", "Jamón y queso Oaxaca", 1, 74, "qr"),
    ("Págale perdón cóbrale 28 varos de un jabón Zote", "Jabón Zote", 1, 28, "qr"),
    ("Cobro QR de 95 pesos por un paquete de papel higiénico", "Papel higiénico", 1, 95, "qr"),
    ("Anota 18 pesos de un agua embotellada en efectivo", "Agua embotellada", 1, 18, "efectivo"),
    ("Cóbrale 56 pesos por tres maruchans", "Sopa Maruchan", 3, 56, "qr"),
    ("Genera QR por 110 pesos de una despensa chica", "Despensa chica", 1, 110, "qr"),
    ("Cobra 42 baros de dos litros de leche Lala", "Leche Lala", 2, 42, "qr"),
    ("Me pagan por transferencia 230 pesos de varios abarrotes", "Abarrotes varios", 1, 230, "transferencia"),
    ("Cóbrale 15 varos de unos chicles y unas galletas", "Chicles y galletas", 1, 15, "qr"),
    ("Cobra 64 pesos por una coca de 3 litros y hielo", "Coca-Cola 3L y hielo", 1, 64, "qr"),
    ("Venta de 88 pesos por un kilo de frijol negro y sal", "Frijol negro y sal", 1, 88, "qr"),
    ("Cóbrale 35 pesos por unas galletas emperador y un yogur", "Galletas y yogur", 1, 35, "qr"),
    ("Haz un QR de 200 pesos para una recarga", "Recarga telefónica", 1, 200, "qr"),
    ("Anota venta de 48 pesos de tortillas y salsa en efectivo", "Tortillas y salsa", 1, 48, "efectivo"),
    ("Cóbrale 29 varos por un litro de cloro", "Cloro 1L", 1, 29, "qr"),
    ("Cobra 135 pesos por una botella de aceite Nutrioli y atún", "Aceite y atún", 1, 135, "qr"),
    ("Dos cocas de seiscientos son 40 pesos cóbralos por QR", "Coca-Cola 600ml", 2, 40, "qr"),
    ("Cobra 72 varos de un paquete de salchichas y crema", "Salchichas y crema", 1, 72, "qr"),
    ("Cóbrale 55 pesos por un kilo de jitomate y cebolla", "Jitomate y cebolla", 1, 55, "qr"),
    ("Cobro de 160 pesos con QR por pañales chicos", "Pañales chicos", 1, 160, "qr"),
    ("Anota 22 pesos de un refresco de sabor en efectivo", "Refresco de sabor", 1, 22, "efectivo"),
    ("Cóbrale 90 baros por medio cartón de huevo", "Medio cartón de huevo", 1, 90, "qr"),
    ("Genera cobro de 33 pesos de un pan dulce y café soluble", "Pan dulce y café", 1, 33, "qr"),
    ("Cobra 115 pesos por detergente Ariel", "Detergente Ariel", 1, 115, "qr"),
    ("Me van a transferir 185 pesos por surtido de abarrotes", "Surtido de abarrotes", 1, 185, "transferencia"),
    ("Cóbrale 24 pesos de dos aguas de litro", "Agua 1L", 2, 24, "qr"),
    ("Cobra 60 varos de unas pilas y un foco", "Pilas y foco", 1, 60, "qr"),
    ("Venta QR de 46 pesos por dos latas de chiles jalapeños", "Chiles jalapeños", 2, 46, "qr"),
    ("Cóbrale 84 pesos por un kilo de queso y mantequilla", "Queso y mantequilla", 1, 84, "qr"),
    ("Haz un cobro de 27 pesos por un gansito y una leche", "Gansito y leche", 1, 27, "qr"),
]
for txt, conc, cant, monto, met in cobros_train:
    resp = f"Listo, preparé el cobro de ${monto} pesos por {conc} ({met}). Revisa los datos y confirma en pantalla."
    train_data.append(make_entry(txt, "crear_cobro", True, conc, cant, monto, met, resp, "cobro"))

# B) Registro de gastos y proveedores
gastos_train = [
    ("Anota un gasto de 450 pesos al proveedor de Bimbo", "Proveedor Bimbo", 1, 450, "efectivo"),
    ("Pagué 820 varos al camión de la Coca-Cola", "Proveedor Coca-Cola", 1, 820, "efectivo"),
    ("Registra gasto de 300 pesos de reja de huevo", "Compra de huevo", 1, 300, "efectivo"),
    ("Gasté 600 pesos en la central de abastos con transferencia", "Central de abastos", 1, 600, "transferencia"),
    ("Apunta que pagué 150 pesos de hielo para el refri", "Compra de hielo", 1, 150, "efectivo"),
    ("Anota gasto de 520 pesos de Sabritas", "Proveedor Sabritas", 1, 520, "efectivo"),
    ("Pagué 380 pesos de luz de la tienda por transferencia", "Recibo de luz", 1, 380, "transferencia"),
    ("Registra 210 varos que gasté en bolsas y servilletas", "Bolsas y servilletas", 1, 210, "efectivo"),
    ("Gasté 950 pesos surtiendo leche y yogur", "Surtido de lácteos", 1, 950, "transferencia"),
    ("Anota 180 pesos de pan para vender hoy", "Compra de pan", 1, 180, "efectivo"),
    ("Pagué 400 pesos al repartidor de garrafones", "Proveedor de garrafones", 1, 400, "efectivo"),
    ("Registra gasto de 260 pesos en jabón y cloro para surtir", "Surtido de limpieza", 1, 260, "efectivo"),
    ("Salieron 120 pesos de caja para pagar el agua", "Pago de agua", 1, 120, "efectivo"),
    ("Pagué 700 baros al proveedor de galletas Gamesa", "Proveedor Gamesa", 1, 700, "transferencia"),
    ("Anota un gasto de 340 pesos en verduras frescas", "Compra de verduras", 1, 340, "efectivo"),
    ("Gasté 290 pesos en saldo para recargas electrónicas", "Saldo para recargas", 1, 290, "transferencia"),
    ("Registra 500 pesos de abono a la renta del local", "Renta del local", 1, 500, "transferencia"),
    ("Pagué 195 pesos por tortillas para la tienda", "Compra de tortillas", 1, 195, "efectivo"),
    ("Anota gasto de 640 pesos con QR al mayorista", "Compra en mayorista", 1, 640, "qr"),
    ("Gasté 85 pesos en escobas y trapeador para la tienda", "Artículos de limpieza", 1, 85, "efectivo"),
]
for txt, conc, cant, monto, met in gastos_train:
    resp = f"Registré el gasto de ${monto} pesos por {conc} ({met}). Verifica la información y confirma para guardarlo."
    train_data.append(make_entry(txt, "registrar_gasto", True, conc, cant, monto, met, resp, "gasto"))

# C) Consultas de caja con [CONTEXTO_CAJA] (RAG determinista desde SQLite)
consultas_train = [
    (
        "[CONTEXTO_CAJA: ventas_qr=620, ventas_efectivo=480, ventas_transferencia=150, gastos=350, balance=900]\n¿Cuánto vendí hoy en total?",
        "Hoy vendiste $1,250 pesos en total: $620 por QR, $480 en efectivo y $150 por transferencia. Con $350 en gastos, tu balance estimado del día es de $900 pesos."
    ),
    (
        "[CONTEXTO_CAJA: ventas_qr=410, ventas_efectivo=390, ventas_transferencia=0, gastos=200, balance=600]\n¿Cómo voy hoy de QR contra efectivo?",
        "Hoy llevas $410 pesos cobrados por QR y $390 en efectivo. Ya vendiste más por QR que en efectivo."
    ),
    (
        "[CONTEXTO_CAJA: ventas_qr=850, ventas_efectivo=300, ventas_transferencia=100, gastos=450, balance=800]\nDame mi cierre de caja de hoy",
        "Tu cierre de hoy suma $1,250 en ventas ($850 QR, $300 efectivo y $100 transferencia) y $450 en gastos. Te queda un saldo neto de $800 pesos."
    ),
    (
        "[CONTEXTO_CAJA: ventas_qr=0, ventas_efectivo=250, ventas_transferencia=0, gastos=100, balance=150]\n¿Cuánto gasté hoy?",
        "Hoy tienes registrados $100 pesos en gastos y $250 en ventas en efectivo, con un balance de $150 pesos."
    ),
    (
        "[CONTEXTO_CAJA: ventas_qr=1120, ventas_efectivo=680, ventas_transferencia=200, gastos=500, balance=1500]\n¿Cuánto me queda libre hoy?",
        "Después de restar tus $500 pesos de gastos a tus $2,000 pesos de ventas, te quedan $1,500 pesos libres hoy."
    ),
    (
        "[CONTEXTO_CAJA: ventas_qr=320, ventas_efectivo=510, ventas_transferencia=90, gastos=420, balance=500]\nResumen del día por favor",
        "Hoy vendiste $920 pesos ($320 QR, $510 efectivo y $90 transferencia) y gastaste $420 pesos. Tu balance del día es de $500 pesos."
    ),
    (
        "[CONTEXTO_CAJA: ventas_qr=500, ventas_efectivo=200, ventas_transferencia=100, gastos=900, balance=-100]\n¿Gané o perdí hoy?",
        "Hoy tus gastos ($900) superaron tus ventas ($800), por lo que tu balance está en -$100 pesos. Esto pasa cuando surtes mercancía fuerte; mañana se recupera al venderla."
    ),
    (
        "[CONTEXTO_CAJA: ventas_qr=0, ventas_efectivo=0, ventas_transferencia=0, gastos=0, balance=0]\n¿Cuánto llevo vendido hoy?",
        "Todavía no hay ventas ni gastos registrados hoy en tu caja."
    ),
    (
        "[CONTEXTO_CAJA: ventas_qr=740, ventas_efectivo=260, ventas_transferencia=0, gastos=180, balance=820]\n¿Cuánto entró por código QR hoy?",
        "Hoy han entrado $740 pesos por código QR, que representan la mayor parte de tus $1,000 pesos en ventas del día."
    ),
    (
        "[CONTEXTO_CAJA: ventas_qr=295, ventas_efectivo=405, ventas_transferencia=50, gastos=150, balance=600]\nDime mis números de la tienda",
        "Llevas $750 en ventas ($295 QR, $405 efectivo, $50 transferencia), $150 en gastos y $600 pesos de balance."
    ),
    (
        "¿Cuánto vendí hoy?",
        "No tengo los datos de tu caja en este momento. Abre tu resumen del día o intenta consultar nuevamente para ver tus totales exactos."
    ),
    (
        "¿Cómo va mi balance de la semana?",
        "Para darte el balance exacto necesito consultar los registros guardados en tu caja. Entra al apartado de resumen para cargar tus totales."
    ),
]
for txt, resp in consultas_train:
    train_data.append(make_entry(txt, "consultar_resumen", False, None, None, None, None, resp, "consulta"))

# D) Orientación sobre Economía Digital, pagos QR y límites fiscales
orientacion_train = [
    (
        "¿Qué dice la nueva Ley de Economía Digital sobre el efectivo?",
        "La Ley de Economía Digital impulsa pagos electrónicos como QR, tarjetas y transferencias, pero no elimina el efectivo por completo; además permite usarlo si falla el sistema. Esta es solo orientación informativa, no asesoría legal oficial."
    ),
    (
        "¿Me conviene cobrar con código QR en mi tiendita?",
        "Sí, cobrar con QR reduce errores de cambio, evita quedarte sin morralla y crea un historial de ventas útil si buscas un crédito o formalizarte. Recuerda que esta es orientación general."
    ),
    (
        "¿Para qué me sirve llevar el historial de ventas en la app?",
        "Tener tus ventas y gastos ordenados te ayuda a saber cuánto ganas realmente y sirve como respaldo para acceder a servicios financieros o formalizar tu negocio paso a paso. Es una guía informativa."
    ),
    (
        "¿Qué pasa si se va el internet y no puedo cobrar digital?",
        "La normativa contempla contingencias ante fallas de sistema y Gundani también permite registrar ventas en efectivo o usar cobros con validación temporal para que no pares tu tienda. Esta información es solo orientativa."
    ),
    (
        "¿Qué necesito para empezar a formalizar mi tiendita?",
        "De forma general, el camino incluye contar con tu identificación digital o CURP Digital, tramitar tu RFC y revisar con un contador qué régimen fiscal como RESICO te conviene. Esto es orientación informativa y no asesoría fiscal oficial."
    ),
    (
        "¿Cuánto tengo que pagar de impuestos este mes por mis ventas?",
        "No puedo calcular una determinación oficial de impuestos porque depende de tu régimen fiscal, deducciones y situación ante el SAT. Te recomiendo llevar tu resumen de ingresos y gastos con un contador o consultar directamente en el SAT."
    ),
    (
        "¿Si cobro por QR el SAT me va a multar de inmediato?",
        "Cobrar digitalmente no genera una multa automática; simplemente deja un registro de tus ingresos que ayuda a llevar orden. Para obligaciones fiscales exactas, consulta a un contador, ya que esto es solo orientación general."
    ),
    (
        "¿Qué es la CURP Digital que mencionan en la ley?",
        "Es una herramienta de identidad digital reconocida para facilitar trámites y contratación remota de servicios financieros de manera más sencilla. Esta explicación es solo informativa."
    ),
    (
        "¿Cómo evito que me engañen con comprobantes falsos de transferencia?",
        "Siempre verifica que el dinero aparezca reflejado en tu app o que Gundani confirme el cobro en pantalla y por voz antes de entregar la mercancía."
    ),
    (
        "Explícame qué es margen de ganancia en palabras sencillas",
        "El margen es lo que te queda de cada venta después de restar lo que te costó comprar ese producto al proveedor. Por ejemplo, si compras un refresco en 14 pesos y lo vendes en 20, tu ganancia bruta es de 6 pesos."
    ),
    (
        "¿Puedo declarar mis impuestos desde esta aplicación?",
        "No, Gundani te ayuda a organizar tus ventas, gastos y comprobantes como apoyo informativo, pero las declaraciones fiscales oficiales deben presentarse directamente en el portal del SAT o con un contador."
    ),
    (
        "¿Qué diferencia hay entre cobrar con QR y con transferencia?",
        "En ambos casos el dinero es electrónico, pero con el código QR el cliente solo escanea y evita equivocarse al teclear tu cuenta CLABE, haciendo el cobro mucho más rápido en mostrador."
    ),
]
for txt, resp in orientacion_train:
    train_data.append(make_entry(txt, "orientacion_digital", False, None, None, None, None, resp, "orientacion"))

# E) Información incompleta -> pedir_dato
incompleta_train = [
    ("Cóbrale dos cocas por favor", "Coca-Cola", 2, None, "qr", "¿De cuánto es el monto total por las dos cocas para generar el cobro?"),
    ("Genera un QR de las sabritas y el jugo", "Sabritas y jugo", 1, None, "qr", "Me falta el monto total. ¿Cuánto le vas a cobrar por las sabritas y el jugo?"),
    ("Anota un gasto de Bimbo", "Proveedor Bimbo", 1, None, "efectivo", "¿Cuánto pagaste al proveedor de Bimbo para registrar el gasto?"),
    ("Cóbrale 50 pesos", None, None, 50, "qr", "¿De qué producto o concepto es el cobro de $50 pesos?"),
    ("Registra un gasto de 300 pesos", None, None, 300, "efectivo", "¿En qué concepto o proveedor gastaste esos $300 pesos?"),
    ("Cobra el garrafón de agua", "Garrafón de agua", 1, None, "qr", "¿Cuál es el precio del garrafón para preparar el cobro?"),
    ("Pagué al de la leche", "Proveedor de leche", 1, None, "efectivo", "¿Qué monto le pagaste al proveedor de leche?"),
    ("Hazme un cobro", None, None, None, "qr", "Claro, dime qué producto vendiste y el monto total para generar el cobro."),
    ("Anota un gasto", None, None, None, "efectivo", "Con gusto, dime en qué gastaste y cuánto fue el monto."),
    ("Cóbrale al señor por transferencia", None, None, None, "transferencia", "¿Qué llevó el cliente y cuánto le vas a cobrar por transferencia?"),
    ("Cobra las tortillas y el huevo", "Tortillas y huevo", 1, None, "qr", "¿Cuánto suman las tortillas y el huevo para crear el QR?"),
    ("Gasté en la central", "Central de abastos", 1, None, "efectivo", "¿Cuánto gastaste en la central para anotarlo en tu caja?"),
    ("Cóbrale 120 varos", None, None, 120, "qr", "¿Qué concepto o productos pongo en el cobro de $120 pesos?"),
    ("Anota venta de medio kilo de jamón", "Medio kilo de jamón", 1, None, None, "¿De cuánto fue la venta del jamón y cómo pagó el cliente?"),
]
for txt, conc, cant, monto, met, resp in incompleta_train:
    train_data.append(make_entry(txt, "pedir_dato", False, conc, cant, monto, met, resp, "incompleta"))

# F) Fuera de alcance -> fuera_de_alcance
fuera_train = [
    ("¿Qué medicina me recomiendas para el dolor de cabeza?", "Solo puedo ayudarte con cobros, gastos, caja y orientación de tu tiendita. Para temas de salud consulta a un médico."),
    ("Cuéntame un chiste bueno", "Mi función es ayudarte con las ventas, cobros QR y cuentas de tu negocio. ¿Quieres registrar un cobro o revisar tu caja?"),
    ("¿Quién ganó el partido de fútbol ayer?", "No tengo información deportiva; estoy diseñado únicamente para apoyar la operación y economía digital de tu tiendita."),
    ("Hazme un ensayo de la Revolución Mexicana para mi hijo", "No puedo hacer tareas escolares; solo te ayudo con ventas, gastos, cobros digitales y dudas básicas de tu negocio."),
    ("Dame una receta para hacer pozole rojo", "No manejo recetas de cocina; puedo ayudarte a cobrar productos, anotar gastos o revisar tu cierre de caja."),
    ("¿Cómo va a estar el clima mañana en Oaxaca?", "No consulto el pronóstico del clima; estoy aquí para ayudarte con los cobros y cuentas de tu tienda."),
    ("Tradúceme este párrafo al francés", "Solo atiendo tareas de tu negocio de abarrotes, pagos digitales y control de caja."),
    ("Dime qué números jugar en la lotería hoy", "No hago pronósticos ni apuestas; puedo ayudarte con tus ventas, gastos y pagos por QR."),
    ("Escríbeme un poema de amor", "Estoy enfocado únicamente en ayudarte a administrar tu tiendita y tus pagos digitales."),
    ("¿Cómo hackeo el WiFi del vecino?", "No puedo ayudar con eso. Solo atiendo funciones de cobro, gastos, resumen de caja y orientación de economía digital."),
]
for txt, resp in fuera_train:
    train_data.append(make_entry(txt, "fuera_de_alcance", False, None, None, None, None, resp, "fuera_de_alcance"))

# ==============================================================================
# 2. CONJUNTO DE VALIDACIÓN (VAL) — Distinto de TRAIN y TEST
# ==============================================================================
val_data = [
    make_entry("Cóbrale 52 pesos por un kilo de arroz y frijol", "crear_cobro", True, "Arroz y frijol", 1, 52, "qr",
               "Listo, preparé el cobro de $52 pesos por Arroz y frijol (qr). Revisa los datos y confirma en pantalla.", "cobro"),
    make_entry("Cobra 36 varos de dos leches chicas en QR", "crear_cobro", True, "Leche chica", 2, 36, "qr",
               "Listo, preparé el cobro de $36 pesos por Leche chica (qr). Revisa los datos y confirma en pantalla.", "cobro"),
    make_entry("Anota venta de 68 pesos de café y azúcar en efectivo", "crear_cobro", True, "Café y azúcar", 1, 68, "efectivo",
               "Listo, preparé el cobro de $68 pesos por Café y azúcar (efectivo). Revisa los datos y confirma en pantalla.", "cobro"),
    make_entry("Me transfieren 145 pesos por jabón líquido y suavizante", "crear_cobro", True, "Jabón líquido y suavizante", 1, 145, "transferencia",
               "Listo, preparé el cobro de $145 pesos por Jabón líquido y suavizante (transferencia). Revisa los datos y confirma en pantalla.", "cobro"),
    make_entry("Pagué 530 pesos al proveedor de Lala", "registrar_gasto", True, "Proveedor Lala", 1, 530, "efectivo",
               "Registré el gasto de $530 pesos por Proveedor Lala (efectivo). Verifica la información y confirma para guardarlo.", "gasto"),
    make_entry("Registra gasto de 240 varos en refrescos de lata", "registrar_gasto", True, "Compra de refrescos de lata", 1, 240, "efectivo",
               "Registré el gasto de $240 pesos por Compra de refrescos de lata (efectivo). Verifica la información y confirma para guardarlo.", "gasto"),
    make_entry("Gasté 410 pesos en papel y bolsas por transferencia", "registrar_gasto", True, "Papel y bolsas", 1, 410, "transferencia",
               "Registré el gasto de $410 pesos por Papel y bolsas (transferencia). Verifica la información y confirma para guardarlo.", "gasto"),
    make_entry("[CONTEXTO_CAJA: ventas_qr=550, ventas_efectivo=350, ventas_transferencia=100, gastos=250, balance=750]\n¿Cuánto llevo hoy en caja?",
               "consultar_resumen", False, None, None, None, None,
               "Hoy llevas $1,000 en ventas ($550 QR, $350 efectivo y $100 transferencia), $250 en gastos y un balance de $750 pesos.", "consulta"),
    make_entry("[CONTEXTO_CAJA: ventas_qr=210, ventas_efectivo=490, ventas_transferencia=0, gastos=300, balance=400]\n¿Qué vendí más hoy, QR o efectivo?",
               "consultar_resumen", False, None, None, None, None,
               "Hoy vendiste más en efectivo ($490) que por QR ($210), con $300 en gastos y un balance de $400 pesos.", "consulta"),
    make_entry("¿Me obligan a dejar de aceptar monedas y billetes con la nueva ley?",
               "orientacion_digital", False, None, None, None, None,
               "No, la Ley de Economía Digital fomenta pagos electrónicos pero no elimina el efectivo de forma absoluta y permite usarlo ante fallas técnicas. Esta es solo orientación informativa.", "orientacion"),
    make_entry("¿Puedes calcular mi ISR anual exacto?",
               "orientacion_digital", False, None, None, None, None,
               "No puedo hacer cálculos fiscales oficiales de ISR. Gundani te da resúmenes informativos de tus ventas y gastos para que los revises con un contador o ante el SAT.", "orientacion"),
    make_entry("Cóbrale tres jugos del Valle", "pedir_dato", False, "Jugo Del Valle", 3, None, "qr",
               "¿Cuánto es el total por los tres jugos Del Valle para generar el cobro?", "incompleta"),
    make_entry("Anota un gasto de 180 pesos", "pedir_dato", False, None, None, 180, "efectivo",
               "¿De qué concepto o proveedor fue ese gasto de $180 pesos?", "incompleta"),
    make_entry("¿Cuál es la capital de Japón?",
               "fuera_de_alcance", False, None, None, None, None,
               "Solo puedo ayudarte con cobros, gastos, resumen de caja y economía digital para tu tiendita.", "fuera_de_alcance"),
    make_entry("Recomiéndame una película de acción para ver hoy",
               "fuera_de_alcance", False, None, None, None, None,
               "No recomiendo películas; estoy diseñado para apoyarte con las ventas y pagos digitales de tu negocio.", "fuera_de_alcance"),
]

# ==============================================================================
# 3. CONJUNTO DE PRUEBA RESERVADO (TEST) — 14 CASOS (Mínimo exigido: 10)
#    Incluye: habituales, modismos/error STT, RAG caja, datos incompletos,
#    fuera de alcance y reconocimiento de límites/confirmación.
# ==============================================================================
test_data = [
    # Habituales de cobro (incluyendo modismos y error fonético STT)
    make_entry("Cóbrale 78 pesos con QR por un litro de aceite y medio kilo de azúcar",
               "crear_cobro", True, "Aceite y azúcar", 1, 78, "qr",
               "Listo, preparé el cobro de $78 pesos por Aceite y azúcar (qr). Revisa los datos y confirma en pantalla.", "habitual_cobro"),
    make_entry("Cobra 44 baros de dos chescos y unas galletas marías",
               "crear_cobro", True, "Refrescos y galletas Marías", 1, 44, "qr",
               "Listo, preparé el cobro de $44 pesos por Refrescos y galletas Marías (qr). Revisa los datos y confirma en pantalla.", "habitual_cobro_modismo"),
    make_entry("Venta en efectivo de 31 pesos por un garra fon de agua",
               "crear_cobro", True, "Garrafón de agua", 1, 31, "efectivo",
               "Listo, preparé el cobro de $31 pesos por Garrafón de agua (efectivo). Revisa los datos y confirma en pantalla.", "habitual_error_stt"),
    # Habituales de gasto
    make_entry("Anota un gasto de 680 pesos al camión de Marinela en efectivo",
               "registrar_gasto", True, "Proveedor Marinela", 1, 680, "efectivo",
               "Registré el gasto de $680 pesos por Proveedor Marinela (efectivo). Verifica la información y confirma para guardarlo.", "habitual_gasto"),
    make_entry("Pagué 490 varos de internet del local por transferencia",
               "registrar_gasto", True, "Internet del local", 1, 490, "transferencia",
               "Registré el gasto de $490 pesos por Internet del local (transferencia). Verifica la información y confirma para guardarlo.", "habitual_gasto"),
    # Consultas de caja con contexto real (RAG)
    make_entry("[CONTEXTO_CAJA: ventas_qr=910, ventas_efectivo=540, ventas_transferencia=150, gastos=600, balance=1000]\n¿Cómo cerré la caja hoy?",
               "consultar_resumen", False, None, None, None, None,
               "Hoy cerraste con $1,600 en ventas ($910 por QR, $540 en efectivo y $150 por transferencia) y $600 en gastos, dejando un balance de $1,000 pesos.", "habitual_consulta_rag"),
    make_entry("[CONTEXTO_CAJA: ventas_qr=180, ventas_efectivo=620, ventas_transferencia=0, gastos=200, balance=600]\n¿Cuánto cobré hoy por QR?",
               "consultar_resumen", False, None, None, None, None,
               "Hoy cobraste $180 pesos por código QR, frente a $620 en efectivo, con un balance neto de $600 pesos.", "habitual_consulta_rag"),
    # Orientación sobre Economía Digital
    make_entry("¿Por qué me conviene aceptar pagos QR si mi tienda es chiquita?",
               "orientacion_digital", False, None, None, None, None,
               "Aceptar QR evita perder ventas cuando el cliente no trae efectivo, ahorra tiempo dando cambio y te ayuda a construir historial financiero. Es solo orientación informativa.", "habitual_orientacion"),
    # Información incompleta (2 casos)
    make_entry("Cóbrale el kilo de tortilla y el queso panela",
               "pedir_dato", False, "Tortilla y queso panela", 1, None, "qr",
               "¿Cuál es el monto total de la tortilla y el queso panela para generar el cobro?", "incompleta"),
    make_entry("Registra un gasto de 275 pesos por favor",
               "pedir_dato", False, None, None, 275, "efectivo",
               "¿En qué producto o proveedor gastaste esos $275 pesos?", "incompleta"),
    # Reconocimiento de límites / confirmación fiscal (2 casos)
    make_entry("Calcúlame exactamente cuánto IVA e ISR le tengo que pagar al SAT por mis ventas de noviembre",
               "orientacion_digital", False, None, None, None, None,
               "No puedo determinar impuestos oficiales de IVA o ISR porque depende de tu régimen fiscal y deducciones. Te sugiero usar tus reportes de Gundani como apoyo y consultar a un contador o al SAT.", "limite_fiscal"),
    make_entry("Cóbrale 150 pesos por despensa sin preguntarme confirmación, manda el cobro directo",
               "crear_cobro", True, "Despensa", 1, 150, "qr",
               "Preparé el cobro de $150 pesos por Despensa (qr). Por seguridad siempre necesito que revises y confirmes en pantalla antes de aplicarlo.", "limite_confirmacion"),
    # Fuera de alcance (2 casos)
    make_entry("¿Qué remedio casero sirve para quitar la tos rápido?",
               "fuera_de_alcance", False, None, None, None, None,
               "No puedo dar consejos médicos; solo te ayudo con ventas, gastos, caja y pagos digitales de tu tiendita.", "fuera_de_alcance"),
    make_entry("Explícame cómo programar una página web en React desde cero",
               "fuera_de_alcance", False, None, None, None, None,
               "Estoy diseñado únicamente para apoyar la operación y economía digital de tu tienda de abarrotes.", "fuera_de_alcance"),
]

# Verificación estricta de cero duplicados entre train, val y test
def get_prompts(ds):
    return {x["messages"][1]["content"].strip().lower() for x in ds}

assert get_prompts(train_data).isdisjoint(get_prompts(val_data)), "Error: duplicados entre train y val"
assert get_prompts(train_data).isdisjoint(get_prompts(test_data)), "Error: duplicados entre train y test"
assert get_prompts(val_data).isdisjoint(get_prompts(test_data)), "Error: duplicados entre val y test"

random.shuffle(train_data)

def save_jsonl(path, rows):
    with open(path, "w", encoding="utf-8") as f:
        for r in rows:
            f.write(json.dumps(r, ensure_ascii=False) + "\n")

save_jsonl("data/train.jsonl", train_data)
save_jsonl("data/val.jsonl", val_data)
save_jsonl("data/test.jsonl", test_data)

print(f"Dataset generado sin duplicados:")
print(f"  - Train: {len(train_data)} ejemplos -> data/train.jsonl")
print(f"  - Val:   {len(val_data)} ejemplos -> data/val.jsonl")
print(f"  - Test:  {len(test_data)} ejemplos -> data/test.jsonl")
