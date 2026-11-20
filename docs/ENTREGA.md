# Lista de entrega (bases, sección 14 y 19)

✅ listo · ✍️ lo completa el equipo · ⏳ falta hacerlo

| Entregable | Dónde | Estado |
|---|---|---|
| **A.** APK instalable | `app/build/app/outputs/flutter-apk/app-release.apk` (compilar con la URL vigente, ver `docs/DEMO.md`) | ✍️ subir al Panel |
| **A.** Instrucciones de instalación y uso, datos de prueba, versión | `docs/DEMO.md`, `README.md`, `docs/pruebas_uso.md` (lista de 10 ventas); versión = commit final | ✅ |
| **B.** Código, entrenamientos, dependencias, conexión app↔modelos | Este repositorio; `README.md` | ✅ |
| **B.** Componentes previos, herramientas de IA, licencias | `docs/DECLARACION_IA_Y_LICENCIAS.md` | ✍️ firma y fecha del líder |
| **B.** Funciones implementadas / simuladas / pendientes | `docs/funciones.md` | ✅ |
| **C.** Paquete de entrenamiento — detector | `training/vision/` (cuaderno, specs, logs, distribución, evaluaciones) + pesos | ✅ `.onnx` + `.engine` en https://drive.google.com/drive/folders/1azEYXom6Bl0GA8qvHUFa2ylVHGPlq_Es (el `.pth` quedó en el DLI, que se reinició) |
| **C.** Paquete de entrenamiento — asistente | `training/asistente/` (datos, config, logs, evaluaciones) + adaptador | ✅ `adaptador_lora/` en https://drive.google.com/drive/folders/1azEYXom6Bl0GA8qvHUFa2ylVHGPlq_Es |
| **C.** Evaluación del detector v1–v3 en el test (106) | `training/detector/evaluar_test_publico.py` (TensorRT, RTX 2060) → `logs/eval_test_publico_v*.json`, tabla en `docs/evidencias.md` | ✅ |
| **D.** Ficha (PDF, ≤ 4 páginas) | `docs/pdf/ficha_proyecto.pdf` (fuente `docs/ficha_proyecto.md`) | ✍️ nombres y cifras de las pruebas de uso |
| **E.** Evidencias | `docs/evidencias.md`, `logs/pruebas_app_2026-11-20.json` | ⏳ pruebas de uso y tiempos |
| **E.** Pruebas con 2 usuarios ajenos | `docs/pruebas_uso.md` | ⏳ |
| **F.** Presentación (PDF) | `docs/pdf/presentacion.pdf` (fuente `docs/presentacion/presentacion.html`) | ✍️ nombres, pruebas de uso, tiempos |
| **G.** Video de respaldo (≤ 3 min) | — | ⏳ grabar |

Regenerar los PDF después de editar las fuentes:

```bash
pandoc docs/ficha_proyecto.md -s --metadata pagetitle="Caja Clara — Ficha" -c docs/pdf/ficha.css -o /tmp/ficha.html --self-contained
google-chrome --headless --no-pdf-header-footer --print-to-pdf=docs/pdf/ficha_proyecto.pdf /tmp/ficha.html
google-chrome --headless --no-pdf-header-footer --allow-file-access-from-files \
  --print-to-pdf=docs/pdf/presentacion.pdf docs/presentacion/presentacion.html
# Documento 02 (modelos de IA); figuras: img/*.mmd → mermaid-cli, curvas desde los logs de entrenamiento
pandoc -f markdown+autolink_bare_uris docs/entregas/02_modelos_ia.md -s --resource-path=docs/entregas:. --metadata pagetitle="Caja Clara — Modelos de IA" \
  -c docs/pdf/ficha.css -c docs/entregas/entregas.css --self-contained -o /tmp/02.html
google-chrome --headless --no-pdf-header-footer --print-to-pdf=docs/entregas/02_modelos_ia.pdf /tmp/02.html
```

Antes de cerrar: revocar la `NVIDIA_API_KEY` usada en desarrollo y verificar que los enlaces del Panel abran
sin iniciar sesión (repositorio público desde el 2026-11-20; documento 02: https://github.com/Rene3FG/caja-clara/blob/main/docs/entregas/02_modelos_ia.pdf).
