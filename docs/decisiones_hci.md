# Decisiones de interacción (HCI)

**Usuaria:** dueña o encargada de una tiendita o puesto de comida en Oaxaca. Atiende sola, con las
manos ocupadas, con señal irregular y anota las ventas en una libreta (cuando le da tiempo).
**Tarea principal:** registrar una venta y su cobro sin dejar de atender.
**Paso que se busca mejorar:** sumar y anotar cada venta a mano (y conciliar después las
transferencias que llegan al celular), que es donde se pierde tiempo y se cometen errores.

---

## 1. La IA propone; la persona revisa y confirma antes de guardar

- **Decisión:** el detector y el asistente nunca guardan nada. Muestran una cuenta propuesta
  ("Propuesta: 2 Sabritas, 3 Coca-Cola · total $106. Revisa y confirma.") que se corrige con +/−,
  agregando o quitando productos, y solo se guarda al tocar Confirmar.
- **Por qué:** se trata de dinero y los modelos se equivocan (el detector pierde chokis en fotos
  mixtas; el asistente a veces asume cantidades). La persona es responsable de su venta y debe
  ver lo mismo que se va a registrar. Las bases (6d) lo exigen.
- **Cómo se verificó:** caso 1 de `evidencias.md` — el detector omitió las chokis; con esta
  decisión ese error se corrige en la cuenta antes de guardar en lugar de quedar registrado. Pruebas de uso: **PENDIENTE** (`pruebas_uso.md`, tarea 1).

## 2. Hablar o escribir, en las palabras de la persona

- **Decisión:** un botón de micrófono grande en toda la app ("cobra 2 sabritas y 3 cocas",
  "quítale el gansito", "¿cómo voy hoy?") y, siempre al lado, un campo para escribir lo mismo.
  El asistente entiende cómo se habla en el mostrador ("cocas", "papitas", "chesco", errores de
  dictado como "la yudas") y responde en frases cortas, sin términos técnicos.
- **Por qué:** con las manos ocupadas, hablar es más rápido que teclear; pero hay ruido y no todos
  los teléfonos tienen dictado, así que escribir debe estar siempre disponible. Si el micrófono no
  está, la app lo dice ("El micrófono no está disponible. Escríbelo aquí.").
- **Cómo se verificó:** 13/14 casos reservados exactos, incluidos dos con errores de dictado
  (`evidencias.md` §3). En la prueba interna en el teléfono se encontró que el dictado se mandaba
  cortado; se corrigió para esperar la frase completa (commit `32bbe93`). Pruebas de uso: **PENDIENTE** (tarea 2).

## 3. Cuando la IA no está segura, pregunta o deja pendiente; nunca adivina

- **Decisión:** si falta el producto o la cantidad, el asistente pregunta ("No escuché qué producto.
  ¿Me dices qué y cuántos?"). Al pasar la libreta por foto, los renglones dudosos o fuera del catálogo
  aparecen como **pendientes** con lo que se leyó, para completar el precio o **Descartar**; y se
  muestra "Lo que leí en tu hoja" para compararlo con el papel. Sin red, las ventas se guardan en el
  teléfono y la pantalla **Sin red** dice qué falta por enviar.
- **Por qué:** un dato inventado que se guarda es peor que una pregunta: descuadra la caja y la
  persona deja de confiar en la app. Mostrar qué se leyó permite detectar el error de un vistazo.
- **Cómo se verificó:** casos 3 y 9 de `evidencias.md`; los errores "1 cable" y "3 tlayudas" que
  salieron en la prueba interna desaparecieron con esta regla. Pruebas de uso: **PENDIENTE** (tarea 3).

---

Mejoras derivadas de pruebas (internas, 2026-11-20): ver la tabla "Errores encontrados en pruebas
internas y corregidos" en `evidencias.md`. Las pruebas con personas ajenas al equipo se registran en
`pruebas_uso.md`.
