# Informe Previo NDC-C4-2025: Comentarios y Recomendaciones

> 🧭 Repositorio público de trabajo para el procesamiento y análisis estructurado de comentarios cualitativos generados en los talleres participativos organizados por el Comité Científico de Cambio Climático en el marco de la actualización de la NDC 2025 de Chile.

---

## Estructura del repositorio

Este repositorio contiene el código, datos y scripts utilizados en dos grandes procesos metodológicos:

```
Informe-Previo-NDC-C4-2025/
├── Sistematización automatizada de comentarios/   ← Preprocesamiento y clasificación con GPT
├── Análisis_comentarios-recomendaciones/         ← Agrupación temática y recomendaciones con Cypher
├── Búsqueda_evidencia/                           ← Revisión de publicaciones científicas relacionadas a recomendaciones
└── README.md                                     ← Este archivo
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

- Detectar similitudes entre comentarios usando embeddings.
- Agrupar comentarios por comunidades temáticas emergentes.
- Generar recomendaciones bottom-up y top-down con contexto metodológico.
- Validar resultados con puntos de control experto.

🔗 Ver detalle: [`README de análisis`](./Análisis_comentarios-recomendaciones/README.md)

---

### 📘 Búsqueda de evidencia científica para recomendaciones
Ubicación: [`/Búsqueda_evidencia`](./Búsqueda_evidencia)

Este componente permite realizar una búsqueda semántica de publicaciones científicas almacenadas localmente, con el objetivo de encontrar referencias relevantes que respalden cada recomendación generada en el análisis participativo.

El flujo permite:

- Generar un embedding de la recomendación.
- Buscar las publicaciones más similares usando `cosine similarity`.
- Clasificar el nivel de vinculación con ayuda de un modelo GPT.
- Generar referencias bibliográficas en formato Harvard con enlace DOI.

🔗 Ver detalle: [`README de búsqueda de evidencia`](./Búsqueda_evidencia/README.md)

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

### 📚 5. Citación recomendada

Si usas este repositorio o alguno de sus componentes en publicaciones, informes u otros desarrollos, cita de la siguiente manera:

> Morales, C. et al. (2025). *Repositorio de análisis estructurado de comentarios NDC 2025* [Software]. Comité Científico de Cambio Climático. GitHub: [github.com/divpoliticas/Informe-Previo-NDC-C4-2025](https://github.com/divpoliticas/Informe-Previo-NDC-C4-2025)

 > ✉️ Contacto: [Carlos Morales Quiroz] · [csmorales@minciencia.gob.cl]
---

> ✉️ Contacto: [Tu nombre o equipo] · [correo institucional]
