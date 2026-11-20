# Gundani — Documento de definición del proyecto

<p class="fuente">Hackathon NVIDIA Oaxaca 2026 · Economía Digital · Digitalización en procesos de negocios · Documento 01 ·
Versión 1.0 · 2026-11-20. Cada cifra viene de un archivo del repositorio; lo que aún no se ha medido se indica como pendiente.</p>

## 1. Datos generales

| Campo | Detalle |
|---|---------|
| **Nombre de la app** | Gundani |
| **Convocatoria** | Hackathon NVIDIA Oaxaca 2026 — categoría Economía Digital (digitalización en procesos de negocios) |
| **Tipo de producto** | App móvil Android (Flutter) con modelos de IA entrenados por el equipo |
| **Proceso que digitaliza** | Registrar una venta y su cobro en una tiendita o puesto de comida, y pasar a digital la libreta de papel |
| **Integrantes del equipo** | Alejandro Cinco Prieto · Luis Daniel Acevedo Herrera · René Fuentes Guzmán · Daniel Eugenio Santibañez Valdivia |
| **Periodo de desarrollo** | 2026-11-19 (primer commit, 15:41) al 2026-11-20 (versión de la demo, commit `63502bd`) |
| **Repositorio** | https://github.com/Rene3FG/caja-clara (público, licencia MIT; el nombre del repositorio es anterior al de la app) |
| **Pesos de los modelos** | https://drive.google.com/drive/folders/1azEYXom6Bl0GA8qvHUFa2ylVHGPlq_Es (ONNX, engine TensorRT, adaptador LoRA, `SHA256SUMS`) |

## 2. Resumen

Gundani es una app para la dueña o encargada de una tiendita o puesto de comida en Oaxaca que hoy anota
sus ventas en una libreta. Con una **foto del mostrador** o **diciendo la venta** ("cobra 2 sabritas y 3 cocas"),
la IA propone la cuenta; la persona la **revisa y corrige**, elige **efectivo, QR o transferencia** (cobro
**simulado**) y confirma. La venta queda en un **libro de ventas** con totales por día, semana o mes. También
puede **pasar a digital una hoja de la libreta** tomándole una foto.

El producto usa tres modelos que **entrenó el equipo** en servidores NVIDIA DLI: un detector de productos
(DINO ResNet-50 con TAO Toolkit, optimizado con TensorRT), un asistente que convierte la voz o el texto en
acciones (Qwen2.5-1.5B + LoRA) y el asistente de caja y cobros simulados (Qwen2.5-3B + QLoRA).
**Los modelos proponen, el código valida y la persona confirma**: nada se guarda sin su aprobación.

## 3. Problema

En las tienditas y puestos de comida la venta se registra —cuando da tiempo— en una libreta. El proceso actual es:

1. El cliente elige sus productos.
2. La vendedora suma de memoria o con calculadora.
3. Cobra en efectivo o por transferencia (y revisa el celular para ver si llegó).
4. Anota en la libreta producto por producto y el total, si le da tiempo.
5. Al cierre cuenta el efectivo y revisa el celular para cuadrar.

**Dónde se pierde:** mientras anota no atiende; las sumas se equivocan; las transferencias quedan sin ligar a
su venta; y al final del día no queda claro cuánto entró en efectivo y cuánto por medios digitales.

**Relación con la economía digital:** la Ley de Economía Digital para Pagos Digitales y Electrónicos impulsa
que estos negocios acepten cobros digitales (DiMo/CoDi). Para eso necesitan primero un **registro confiable
que ligue cada cobro con su venta**. Gundani es ese primer paso, hecho a la velocidad del mostrador.

## 4. Usuaria y partes interesadas

| Parte | Descripción | Qué necesita |
|---|---|---|
| **Usuaria principal** | Dueña o encargada que atiende sola, con las manos ocupadas, señal irregular y poca costumbre de usar apps de punto de venta | Registrar la venta sin dejar de atender; ver cuánto lleva; no perder ventas sin señal |
| Clientes del negocio | Compran y pagan en efectivo o con transferencia/QR | Cobro rápido y correcto |
| Jurado y organización del hackathon | Evalúan el uso de herramientas NVIDIA, el entrenamiento propio y el impacto | Evidencia reproducible: datos, métricas, hashes de los modelos en uso |
| Equipo de desarrollo | Construye y mantiene la app, los modelos y los servidores | Requisitos claros, alcance acotado |

Decisiones de diseño para esta usuaria (detalle en `docs/decisiones_hci.md`): la IA propone y la persona
confirma; hablar o escribir con sus propias palabras ("cocas", "papitas", "chesco"); si la IA no está segura,
pregunta o deja el renglón pendiente, nunca adivina.

## 5. Objetivos

**Objetivo general.** Digitalizar el registro de la venta y su cobro en micronegocios de Oaxaca, de forma que
tome menos pasos que la libreta, calcule los totales sin errores y deje cada cobro ligado a su venta.

**Objetivos específicos (medibles).**

| # | Objetivo | Indicador | Estado |
|-|-----|--------|--|
| O1 | Reconocer y contar productos en una foto del mostrador | Detector v3: conteo exacto 67 % y 11 % de falsos positivos en fotos propias reservadas (p03, 36 fotos); mAP 0.857 / mAP50 1.000 en el test público (106 imágenes); 89 ms por foto en RTX 2060 | ✅ medido |
| O2 | Entender ventas dichas o escritas en lenguaje del mostrador | Asistente: coincidencia exacta 1.4 % (base) → 86.5 % (LoRA) en 74 casos; reservados 0/14 → 13/14; JSON válido 45.9 % → 100 % | ✅ medido |
| O3 | Responder consultas de caja y cobros simulados | Asistente de caja: intención exacta 57.1 % → 85.7 %; monto correcto 42.9 % → 100 % (14 casos) | ✅ medido |
| O4 | Reducir los pasos para registrar una venta | Libreta: 5 pasos manuales → Gundani: 4 pasos con total calculado | ✅ conteo del flujo |
| O5 | Reducir el tiempo y los errores por venta | 10 ventas de una lista fija, libreta contra app, con 2 personas ajenas al equipo (`docs/pruebas_uso.md`) | ⏳ pendiente |
| O6 | Funcionar sin señal | Ventas y gastos se guardan en el teléfono y se envían al volver la conexión | ✅ implementado |

## 6. Alcance

### 6.1 Dentro del alcance

- **Venta por foto:** el detector reconoce 7 productos de tiendita (chokis, coca_cola, doritos, gansito,
  panditas, sabritas, skittles) y marca `otro_producto` como no reconocido.
- **Venta por voz o texto:** agregar, quitar, elegir forma de pago; preguntar si falta información; rechazar lo
  que está fuera de alcance.
- **Revisión y corrección** de la cuenta (+/−, agregar del catálogo, borrar) antes de guardar.
- **Cobro** en efectivo, QR o transferencia (muestra CLABE y titular) — QR y transferencia **simulados**.
- **Libro de ventas:** periodos Hoy, Semana, Mes y Fechas; ganancia, total de ventas, salidas de dinero,
  desglose de ventas y pagos; registro de gastos.
- **Libreta a digital:** foto o texto de la hoja → revisión de renglones y fecha → se guarda como ventas de ese día.
- **Productos del mostrador:** lista, precio, alta y edición.
- **Consultas por voz** con los números del teléfono: ventas, efectivo, lo más y lo menos vendido.
- **Trabajo sin señal** con cola de envío; **voz de respuesta** (TTS) que lee los montos en pesos.
- **Transparencia:** la app muestra el `sha256` de los modelos que están cargados (Libro → Modelos de IA en uso).

### 6.2 Fuera del alcance

- Mover dinero real: no hay conexión con bancos, CoDi/DiMo de Banxico ni billetera; todo cobro digital es simulado
  y la app lo indica con la etiqueta **«Codi (simulado)»**.
- Facturación, inventario completo, contabilidad fiscal o asesoría financiera personalizada.
- Reconocer productos fuera de los 7 entrenados (se agregan a mano desde el catálogo).
- iOS como plataforma de entrega (el entregable es el APK de Android).
- Pantalla de fiados (se guardan en el teléfono, sin pantalla).

## 7. Solución propuesta

**Recorrido principal — registrar una venta**

1. La persona toma una **foto** de los productos en el mostrador (o los dicta/escribe).
2. El **detector** (o el **asistente**) propone la cuenta; el código calcula precios y total.
3. La persona **revisa y corrige** la cuenta.
4. Elige **efectivo, QR o transferencia** (simulado: aprobado / QR expirado / saldo insuficiente).
5. **Confirma**: la venta se guarda y se consulta después en el libro.

**Recorrido secundario — pasar la libreta a digital.** Foto de la hoja → Nemotron 3.5 Super VL (servicio de
NVIDIA, complemento) la transcribe → nuestro LoRA la interpreta → la persona revisa, completa los renglones
pendientes y guarda con la fecha que elija.

**Comparación con el proceso actual**

| Medida | Libreta (hoy) | Gundani |
|---|---|---|
| Pasos por venta de 3 productos con cobro | 5 manuales: sumar, anotar productos, anotar total, revisar transferencia, anotarla | 4: foto o voz, revisar, elegir cobro, confirmar; total calculado por la app |
| Cobro digital ligado a la venta | No (se revisa el celular aparte) | Sí, en el mismo registro |
| Tiempo y errores en 10 ventas | Pendiente (pruebas de uso) | Pendiente (pruebas de uso) |

## 8. Requisitos

### 8.1 Funcionales

| ID | Requisito | Estado |
|--|------------|----|
| RF-01 | Primer uso: guía y perfil (negocio, persona, CLABE opcional de 18 dígitos); sin negocio y nombre no entra a la caja | ✅ |
| RF-02 | Detectar y contar productos en una foto (`POST /detectar`) | ✅ |
| RF-03 | Convertir voz o texto en una acción JSON (`POST /asistente`) que la app muestra para confirmar | ✅ |
| RF-04 | Editar la cuenta (cantidades, quitar, borrar todo, agregar del catálogo) | ✅ |
| RF-05 | Cobro en efectivo, QR (simulado) y transferencia (CLABE y titular para copiar) | ✅ |
| RF-06 | Pantalla de pago confirmado y pantalla de error si el cobro no se anotó | ✅ |
| RF-07 | Libro con periodos, ganancia, ventas, salidas y desgloses; anotar gastos | ✅ |
| RF-08 | Libreta a digital por foto o texto (`POST /libreta`), con renglones pendientes | ✅ |
| RF-09 | Alta y edición de productos del mostrador | ✅ |
| RF-10 | Consultas de caja por voz con el periodo del libro | ✅ |
| RF-11 | Guardar sin señal y enviar al servidor de caja al volver la conexión | ✅ |
| RF-12 | Cambiar la dirección del servidor de IA sin recompilar (Perfil → Servidor IA → Probar conexión) | ✅ |
| RF-13 | Guía financiera con respuestas verificadas (RAG, `POST /api/guia/preguntar`) | ✅ en el backend |
| RF-14 | Volver a abrir la guía desde el perfil; pantalla de fiados | ⏳ pendiente |

### 8.2 No funcionales

| ID | Requisito | Cómo se cumple |
|--|-------|--------|
| RNF-01 | **Seguridad del dato:** nada se guarda sin confirmación; el modelo no inventa precios ni productos | El servidor valida que el producto exista en el catálogo **y que la persona lo haya mencionado**; precios y totales se calculan en código |
| RNF-02 | **Rendimiento:** respuesta a la velocidad del mostrador | Detector 89 ms (mediana, RTX 2060); asistente 0.8–1.1 s; cobro QR simulado 585 ms |
| RNF-03 | **Tolerancia a fallas:** la venta no se pierde si un servicio cae | El gateway responde 503/504 con "Puedes capturar a mano"; cola local sin señal |
| RNF-04 | **Usabilidad:** lenguaje del mostrador, frases cortas, botones grandes | Orbe de voz «Cempasúchil», campo de texto siempre disponible, voz que lee montos en pesos |
| RNF-05 | **Trazabilidad de modelos:** demostrar qué modelo está en uso | `GET /salud` y la app muestran el `sha256` del engine y del adaptador cargados |
| RNF-06 | **Secretos fuera del código** | `NVIDIA_API_KEY` y `ROBOFLOW_API_KEY` en `.env`, excluido por `.gitignore` |
| RNF-07 | **Reproducibilidad** | Scripts de datos, specs, logs y evaluaciones en `training/`; pesos con `SHA256SUMS` |

## 9. Arquitectura y tecnología

| Capa | Componente | Tecnología |
|---|---|---|
| App | APK Android (`app/`) | Flutter/Dart; cámara, `speech_to_text` (STT de Android), `flutter_tts`, `connectivity_plus`, `shared_preferences` |
| Gateway | `scripts/ia_gateway.py`, puerto 8000 | FastAPI; rutas `/detectar`, `/asistente`, `/libreta`, `/salud`; reenvía `/api/*` al servidor de caja |
| Detector | `training/detector/servir_detector.py`, puerto 8002 | DINO ResNet-50 v3 · TAO Toolkit 5.5 → ONNX → TensorRT 11.5 · RTX 2060 |
| Asistente | `training/asistente/servir_asistente.py`, puerto 8001 | Qwen2.5-1.5B-Instruct + LoRA r=16 (PEFT), fp16 · RTX 2060; Nemotron 3.5 Super VL vía API para la libreta |
| Caja | `backend_gundani/` en VPS | Qwen2.5-3B + QLoRA 4 bits → GGUF Q4_K_M en `llama-server`; SQLite; guía RAG |
| Acceso público | Cloudflare Tunnel | HTTPS hacia la laptop; la URL cambia en cada reinicio |
| Entrenamiento | Servidores NVIDIA DLI | Tesla T4; contenedores de TAO / PyTorch de NGC |

**Modelos del producto**

| Modelo | Función | Datos | Entrenado por el equipo |
|---|---|---|---|
| Detector DINO ResNet-50 (v1, v2, v3; la app usa v3) | Reconocer y contar productos en la foto | 819–930 imágenes de train: datasets públicos CC BY 4.0 + fotos propias (sesiones p01, p02, p04; p03 reservada para la prueba) | Sí — 3 versiones |
| Qwen2.5-1.5B-Instruct + LoRA | Voz/texto → acción (agregar, quitar, pago, consulta, libreta, aclarar) | 1,165 ejemplos sintéticos revisados; 113 val; 122 test; 14 reservados | Sí |
| Asistente de caja: Qwen2.5-3B + QLoRA | Consultas de caja y cobros simulados | 108 ejemplos de train, 15 de validación | Sí |
| Nemotron 3.5 Super VL (build.nvidia.com) | Transcribir la hoja de la libreta | — | No: servicio de NVIDIA, declarado como complemento |

Detalle completo de entrenamiento, evaluación y despliegue: **Documento 02 — Modelos de IA**
(`docs/entregas/02_modelos_ia.pdf`).

## 10. Supuestos y restricciones

**Supuestos**

- La usuaria tiene un teléfono Android con cámara y micrófono, y datos o wifi la mayor parte del día.
- Los productos más vendidos de una tiendita se pueden cubrir con un catálogo pequeño; el resto se agrega a mano.
- La persona está dispuesta a revisar la cuenta propuesta antes de confirmar.

**Restricciones**

- Tiempo: desarrollo de ~2 días dentro del hackathon (2026-11-19 y 2026-11-20).
- Cómputo: entrenamiento solo en los servidores NVIDIA DLI (Tesla T4), que se reinician y no conservan archivos
  (el `.pth` de v3 se perdió; quedan ONNX y engine con su hash); inferencia en una laptop con RTX 2060 de 6 GB.
- Pagos: por las bases y por seguridad, ningún cobro mueve dinero real.
- Datos: sin datos personales; las fotos con caras se excluyeron.

## 11. Riesgos y mitigación

| Riesgo | Impacto | Mitigación |
|---|---|---|
| El detector omite o confunde un producto (p. ej. chokis en fotos mixtas) | Venta con cuenta incorrecta | La persona revisa y corrige antes de guardar; v2 y v3 se entrenaron con fotos propias para bajar falsos positivos (100 % → 11 %) |
| El asistente inventa un producto o cantidad | Registro falso | El servidor rechaza productos no mencionados; pregunta si falta información |
| La laptop, el túnel o la red se caen durante la demo | La IA deja de responder | Captura a mano, cola sin señal, URL del servidor editable desde el perfil y `scripts/demo_up.sh` para levantar todo de nuevo |
| El servidor de caja (VPS) no responde | No se anota el cobro en la caja | El teléfono guarda el cobro y lo envía después |
| La URL del túnel cambia al reiniciar | La app apunta a una dirección muerta | Cambiarla en Perfil → Servidor IA, sin recompilar |
| Confusión entre cobro real y simulado | Expectativa equivocada de la usuaria | Etiqueta «Codi (simulado)» en todas las pantallas de cobro |
| Pérdida de pesos al reiniciarse el DLI | No poder reproducir el modelo | Pesos exportados a Drive con `SHA256SUMS`; specs y logs en el repositorio |

## 12. Criterios de aceptación

- La app instalada desde el APK registra una venta por foto, por voz y por texto, la cobra (simulado) y la muestra en el libro.
- Los hashes que muestra la app coinciden con los de `modelos/README.md` y con los archivos entregados.
- Ningún producto o monto se guarda sin confirmación de la persona.
- La venta registrada sin señal aparece en la caja al volver la conexión.
- Pruebas de uso con al menos 2 personas ajenas al equipo, con tiempo y errores medidos contra la libreta (pendiente).

## 13. Entregables y estado

| Entregable | Ubicación | Estado |
|---|---|---|
| APK instalable | `app/build/app/outputs/flutter-apk/app-release.apk` | ✅ compilado e instalado en dos teléfonos (2026-11-20) |
| Código, entrenamiento y conexión app ↔ modelos | Repositorio; `README.md`, `docs/DEMO.md` | ✅ |
| Paquetes de entrenamiento (detector y asistente) y pesos | `training/`; Drive con `SHA256SUMS` | ✅ |
| Documento 01 — Definición del proyecto | `docs/entregas/01_definicion_proyecto.pdf` / `.docx` | ✅ este documento |
| Documento 02 — Modelos de IA | `docs/entregas/02_modelos_ia.pdf` / `.docx` | ✅ |
| Funciones implementadas / simuladas / pendientes | `docs/funciones.md` | ✅ |
| Declaración de IA y licencias | `docs/DECLARACION_IA_Y_LICENCIAS.md` | ✍️ falta firma y fecha de los integrantes |
| Ficha del proyecto (PDF) | `docs/pdf/ficha_proyecto.pdf` | ✍️ faltan nombres y cifras de pruebas de uso |
| Evidencias y pruebas de uso | `docs/evidencias.md`, `docs/pruebas_uso.md` | ⏳ faltan pruebas con 2 personas ajenas |
| Presentación (PDF) | `docs/pdf/presentacion.pdf` | ✍️ faltan nombres y tiempos |
| Video de respaldo (≤ 3 min) | — | ⏳ por grabar |

## 14. Cronograma (según el historial de git)

| Fecha y hora | Hito |
|---|--------|
| 2026-11-19 15:41 | Estructura inicial del proyecto; scripts del detector (TensorRT) y del asistente LoRA |
| 2026-11-19 23:42 | Datos, spec y log del entrenamiento del detector DINO |
| 2026-11-20 00:51–05:31 | Interfaz de la app: alineación, revisiones de flujo y pantalla de inicio (GUN-04 a GUN-07) |
| 2026-11-20 06:28 | Demo funcional: gateway de IA + túnel; foto, voz y libreta con los modelos del equipo; cobro simulado |
| 2026-11-20 08:12–08:39 | Libreta leída de lado; documentación de entrega; campo Servidor IA en el perfil |
| 2026-11-20 10:22–10:46 | Documento 02 completo, pesos públicos en Drive |
| 2026-11-20 11:18–11:44 | Libreta a mano con pendientes; guía financiera RAG del servidor de caja |
| 2026-11-20 12:09 | Versión de la demo (`63502bd`): APK con el túnel vigente instalado en los teléfonos |

## 15. Siguientes pasos

1. Hacer las **pruebas de uso** con 2 personas ajenas al equipo y llenar tiempos y errores (`docs/pruebas_uso.md`).
2. Completar la firma de la declaración, ficha y presentación; grabar el video de respaldo.
3. Revocar la `NVIDIA_API_KEY` de desarrollo al cerrar la entrega.
4. **Escalamiento (plan, no medido):** servir los modelos con NVIDIA NIM o el detector en un Jetson por tienda para
   no depender de la laptop ni del túnel; cuantizar (engine FP16/INT8, asistente en 4 bits) para GPUs más pequeñas;
   ampliar el catálogo del detector con fotos de cada tienda; conectar con CoDi/DiMo real cuando exista un convenio.

## 16. Firmas del equipo

| Rol | Nombre | Firma | Fecha |
|---|-----|----|--|
| Integrante del equipo | Alejandro Cinco Prieto | | |
| Integrante del equipo | Luis Daniel Acevedo Herrera | | |
| Integrante del equipo | René Fuentes Guzmán | | |
| Integrante del equipo | Daniel Eugenio Santibañez Valdivia | | |
