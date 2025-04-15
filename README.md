# Informe Previo NDC-C4-2025: Comentarios y Recomendaciones

> 🧭 Repositorio público de trabajo para el procesamiento y análisis estructurado de comentarios cualitativos generados en los talleres participativos organizados por el Comité Científico de Cambio Climático en el marco de la actualización de la NDC 2025 de Chile.

---

## Estructura del repositorio

Este repositorio contiene el código, datos y scripts utilizados en dos grandes procesos metodológicos:

```
Informe-Previo-NDC-C4-2025/
├── Sistematización automatizada de comentarios/  ← Preprocesamiento y clasificación con GPT
├── Análisis_comentarios-recomendaciones/    ← Búsqueda y agrupación temática con CQL (Cypher)
└── README.md                                ← Este archivo
```

---

## 1. Propósito general

Durante los **Diálogos Científicos por la Acción Climática** impulsados por el Comité Científico de Cambio Climático (C4), se recogieron cientos de comentarios cualitativos a través de talleres virtuales y presenciales organizados por **mesas temáticas**.

Este repositorio reúne herramientas que permiten transformar dichos aportes en insumos procesables para análisis posteriores. Las herramientas han sido desarrolladas por el equipo del Comité Científico, con énfasis en la **trazabilidad, reproducibilidad y adecuación metodológica** de los resultados.

---

## 2. Componentes principales

### 🟢 Sistematización automatizada de comentarios
Ubicación: [`/Sistematización automatizada de comentarios`](./Sistematización%20automatizada%20de%20comentarios)

Contiene un flujo automatizado en Python que:

- Descarga comentarios desde hojas de cálculo colaborativas.
- Clasifica cada comentario (estratégico, técnico, crítico o no interpretable).
- Reescribe cada aporte como una frase completa, usando modelos de lenguaje (OpenAI GPT).
- Aplica un contexto específico por mesa temática.
- Exporta un CSV estructurado con resultados para análisis posteriores.

🔗 Ver detalle: [`README de sistematización`](./Sistematización%20automatizada%20de%20comentarios/README.md)

---

### 🔷 Análisis de comentarios y recomendaciones
Ubicación: [`/Análisis_comentarios-recomendaciones`](./Análisis_comentarios-recomendaciones)

Contiene archivos `.cql` con **consultas semánticas y de red** para su uso en **Neo4j**, que permiten:

- Buscar publicaciones relevantes por mesa temática.
- Agrupar comentarios procesados mediante embeddings.
- Detectar similitudes temáticas y generar recomendaciones.
- Explorar relaciones entre comentarios y temáticas.

🔗 Ver detalle: `README` en construcción

---

## 3. Contexto de uso

Este repositorio fue diseñado como insumo para el **informe previo** del Comité Científico en el marco de la revisión participativa de la NDC 2025. Se espera que su contenido sea útil para:

- Equipos analíticos que necesiten depurar y mapear grandes volúmenes de comentarios.
- Investigadores interesados en la trazabilidad del proceso participativo.
- Entidades públicas que busquen reproducir este enfoque en futuras consultas.

---

## 4. Créditos y licencia

Este trabajo fue desarrollado por el equipo de la Secretaría Técnica del Comité Científico de Cambio Climático de Chile, con la colaboración de investigadores participantes en los talleres.

- Código: MIT License  
- Documentación y prompts: CC-BY-SA 4.0

---

> ✉️ Contacto: [Tu nombre o equipo] · [correo institucional]
