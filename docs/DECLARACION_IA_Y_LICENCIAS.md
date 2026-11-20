# Caja Clara — Declaración de uso de IA, componentes previos y licencias

Hackathon NVIDIA Oaxaca 2026 · Economía Digital · Bases secciones 9, 10 y 14B

---

## 1. Declaración del uso de IA (texto de la sección 9)

> Para la elaboración de este trabajo se utilizó **Claude (Anthropic)** como apoyo en la planeación técnica paso a paso, la redacción de borradores de scripts (preparación de datos, generación del dataset sintético del asistente, entrenamiento LoRA, evaluación, servidores FastAPI y conversión a TensorRT), la depuración de errores en los servidores, y la elaboración de documentación y PDFs de apoyo; **Google Stitch (Google)** como apoyo en el prototipado visual de las pantallas de la app; y un **asistente de código local** como apoyo en la revisión del repositorio y la realización de commits. Quienes firman este trabajo han revisado y editado el contenido, verificado las fuentes y asumen plena responsabilidad por la versión final.

Precisiones:
- Todos los entrenamientos, evaluaciones y pruebas fueron **ejecutados por el equipo** en los servidores NVIDIA DLI y en la laptop del equipo; los resultados reportados salen de esos registros (`logs/`, `resultados_*`).
- Las etiquetas de las fotos propias se pre-generaron con nuestro detector v1 y **se revisaron y corrigieron a mano** en Roboflow; 7 correcciones adicionales quedan registradas en `correcciones_manuales.txt`.
- La IA de apoyo no forma parte del producto: la app solo usa los modelos listados en la sección 2.

Firma del líder del equipo: ______________________ Fecha: ____________

---

## 2. Componentes de IA del producto

| Componente | Quién lo hizo | Función en Caja Clara |
|---|---|---|
| **Detector DINO ResNet-50 (v1 y v2)** | **Entrenado por el equipo** (TAO Toolkit, Tesla T4 DLI) | Reconocer y contar productos en la foto de la venta |
| **Adaptador LoRA sobre Qwen2.5-1.5B-Instruct** | **Entrenado por el equipo** (PEFT, Tesla T4 DLI) | Convertir lo que dice/escribe la vendedora en acciones (agregar, quitar, pago, libreta…) |
| Nemotron 3.5 Super VL (API build.nvidia.com) | NVIDIA (servicio ya entrenado, **complemento**) | Transcribir la foto de la hoja de la libreta; nuestro LoRA interpreta el texto |
| Nemotron 3.5 Bolt E4B (API build.nvidia.com) | NVIDIA (**solo referencia**) | Comparación de desempeño contra nuestro asistente; no se usa en la app |
| Reconocimiento de voz de Android | Google (sistema del teléfono) | Voz → texto antes de enviarlo al asistente |

Conforme a la sección 7 de las bases, el servicio de OCR/visión de NVIDIA se usa como **complemento**; el componente visual que acredita el requisito es el **detector entrenado por el equipo**.

---

## 3. Modelos base, datos y licencias

> Verificar cada enlace antes de entregar; las marcadas con ⚠ deben confirmarse en su página oficial.

| Componente | Procedencia | Licencia |
|---|---|---|
| DINO ResNet-50 preentrenado COCO (`nvidia/tao/pretrained_dino_coco:dino_resnet_50_trainable_v1.0`, sha256 `7a391fb8…`) | NGC (NVIDIA) | Licencia de modelos NVIDIA / TAO ⚠ |
| TAO Toolkit 5.5.0 (contenedores `tao-toolkit:5.5.0-pyt`) | NGC (NVIDIA) | TAO Toolkit EULA |
| TensorRT 10 (DLI) y 11.5 (laptop) | NVIDIA | NVIDIA Software License ⚠ |
| Qwen2.5-1.5B-Instruct | Hugging Face (Qwen / Alibaba Cloud) | Apache 2.0 ⚠ |
| Nemotron 3.5 Super VL | build.nvidia.com | OpenMDW 1.1 (según la página del modelo) |
| Nemotron 3.5 Bolt E4B | build.nvidia.com | ⚠ confirmar |
| **ProductosOXXO_V02** v3 — universe.roboflow.com/ipsum/productosoxxo_v02 | Roboflow Universe (autor: Ipsum) | CC BY 4.0 |
| **Dataset Mercado** v1 — universe.roboflow.com/fundamentosia/dataset-mercado | Roboflow Universe (autor: FundamentosIA) | CC BY 4.0 |
| Fotos propias (sesiones p01, p02, p03) | Tomadas por el equipo; sin rostros ni datos personales | Propias (CC BY 4.0 en Roboflow) |
| Dataset del asistente (~1,400 frases) | **Sintético**, generado con `generar_dataset.py` y revisado por el equipo | Propio |
| PyTorch, Transformers, PEFT, Accelerate, FastAPI, Uvicorn, Pillow | PyPI | BSD / Apache 2.0 / MIT |
| Flutter (app) | Google | BSD-3 |

Datos sintéticos (sección 10): el dataset del asistente es sintético y está identificado como tal; los catálogos y precios de demostración son ficticios.

---

## 4. Funciones implementadas, simuladas y pendientes (sección 14B)

| Función | Estado |
|---|---|
| Detección y conteo de productos por foto (detector propio, TensorRT) | Implementada |
| Asistente de pedidos por voz/texto (LoRA propio) con confirmación | Implementada |
| Pasar la libreta a digital por dictado/texto | Implementada |
| Pasar la libreta a digital por foto (Nemotron VL + LoRA) | Implementada, **requiere internet** |
| Revisión y corrección antes de guardar | Servidores listos · pantalla en la app: *[completar]* |
| Manejo de errores (foto inválida, sin detecciones, servidor caído) | Servidores listos · app: *[completar]* |
| Hash de los modelos en la app | Endpoint `/salud` listo · pantalla: *[completar]* |
| Cobro en efectivo / transferencia (DiMo/CoDi) | **Simulado** (estados pendiente / pagado / falló) |
| Cierre de caja | *[completar]* |
| Detector con las 7 clases evaluado en fotos propias | **Pendiente**: solo sabritas y chokis evaluadas con fotos propias |

---

## 5. Secretos

No se incluyen llaves en el repositorio. Las llaves de NVIDIA (`NVIDIA_API_KEY`) y Roboflow se leen de variables de entorno (`.env`, fuera de git). Las llaves usadas durante el desarrollo fueron revocadas al terminar.
