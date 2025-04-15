# Evaluación Semántica de Evidencia Científica para Recomendaciones

> 📚 Este módulo contiene scripts Cypher (`.cql`) diseñados para ejecutarse en una base de datos **Neo4j** paralela que almacena publicaciones científicas con embeddings vectoriales. Permite buscar, clasificar y justificar evidencia científica relevante para recomendaciones de política climática generadas en el marco de la NDC 2025, mediante un proceso automatizado basado en NLP y revisión estructurada.

---

## 1. Propósito general

Este componente tiene como objetivo fortalecer la **validez empírica** de las recomendaciones generadas (ya sea bottom-up o top-down), mediante una evaluación semántica de su correspondencia con publicaciones científicas indexadas. Utiliza modelos de lenguaje para:

- Ejecutar búsquedas semánticas sobre una base de publicaciones previamente embebida.
- Identificar los artículos más similares a una recomendación específica.
- Clasificar el nivel de vínculo entre la evidencia y la recomendación (alto, parcial, nulo).
- Generar justificaciones y referencias bibliográficas en formato Harvard.

---
## 2. Proceso general

El script realiza una evaluación por recomendación, siguiendo los pasos descritos a continuación:

### 🔹 1. Definición de recomendación y términos de búsqueda

Se define una recomendación a evaluar, junto con una versión bilingüe (inglés/español) para maximizar la cobertura semántica en la base de publicaciones.

```cypher
WITH ["**English Version** ...", "**Versión en Español** ..."] AS searchTerms,
     "Texto de la recomendación" AS recomendacion
```

### 🔹 2. Generación de embedding de búsqueda

Se genera un embedding vectorial para la búsqueda a partir de `searchTerms` mediante la API de OpenAI.

```cypher
CALL apoc.ml.openai.embedding(searchTerms, $apiKey, { model: 'text-embedding-3-small' }) 
YIELD embedding
```

### 🔹 3. Búsqueda de publicaciones por similitud semántica

Se compara el embedding generado contra todos los nodos `:Record` (publicaciones), y se seleccionan las 10 más cercanas según similitud coseno.

```cypher
MATCH (r:Record)
WITH r, gds.similarity.cosine(r.embedding, queryEmbedding) AS similarity
ORDER BY similarity DESC
LIMIT 10
```

### 🔹 4. Construcción del cuerpo de evidencia

Se formatea la información esencial de cada publicación (título, autores, resumen, año, journal, volumen y DOI) en una narrativa legible para su evaluación posterior.

```cypher
apoc.text.join([...], "\n\n") AS textoEvidencias
```

### 🔹 5. Evaluación con modelo GPT

Se entrega la recomendación junto al texto de evidencias a un modelo de lenguaje, el cual:

- Clasifica cada publicación como **vinculada altamente**, **vinculada parcialmente** o **no vinculada**.
- Justifica la clasificación con base en su contenido.
- Genera una referencia bibliográfica en formato Harvard por cada publicación, enlazando el DOI.

```cypher
CALL apoc.ml.openai.chat([...]) YIELD value
```

📌 *Resultado:* Se obtiene una justificación detallada en formato de lista, lista para integrarse a informes técnicos o anexos de respaldo.

---

## 3. Consideraciones metodológicas

- La base de publicaciones debe contar con embeddings precargados (`:Record.embedding`).
- El sistema puede operar tanto con recomendaciones generadas automáticamente como con recomendaciones redactadas manualmente por el equipo.
- El modelo usado para clasificación (`gpt-4o-mini`) ha sido ajustado mediante instrucciones específicas que aseguran una lectura técnica y estructurada de la evidencia.
- El enfoque de evaluación no impone un umbral de corte, sino que prioriza el análisis cualitativo de vínculo temático.

---

## 4. Resultados esperados

- Priorización automática de referencias científicas según pertinencia.
- Clasificación cualitativa de vínculo temático con la recomendación.
- Generación de bibliografía en formato académico estandarizado (Harvard).
- Registro trazable de las evidencias consultadas por cada recomendación.
