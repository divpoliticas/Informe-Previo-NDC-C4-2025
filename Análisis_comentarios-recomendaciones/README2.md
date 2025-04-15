# Análisis de Comentarios Reescritos por Mesa Temática

> 🧠 Este módulo contiene scripts Cypher (`.cql`) para su uso en **Neo4j**, diseñados como parte de una metodología de análisis estructurado de aportes científicos recolectados en los talleres participativos del Comité Científico de Cambio Climático (NDC 2025). El flujo integra técnicas de inteligencia artificial, análisis semántico, algoritmos de clusterización y validación experta para identificar patrones, generar recomendaciones y sintetizar resultados de forma rigurosa y trazable.

---

## 1. Propósito general

Este componente se centra en la **organización temática** y el **análisis semántico avanzado** de los comentarios reescritos. A partir de los insumos previamente sistematizados (ver carpeta de `Sistematización Automatizada de comentarios`), se aplica un enfoque mixto de análisis inductivo y deductivo para:

- Carga y organización semántica de los comentarios.
- Carga estructurada del texto base de la NDC.
- Identificar patrones emergentes y comunidades temáticas mediante clustering.
- Validación de temáticas detectadas con expertos (no presente en el código).
- Relacionar cada comentario con **temáticas validadas por expertos** usando similitud semántica.
- Relacionar cada comentario con la base de datos del texto de la NDC.
- Generación de recomendaciones con enfoques inductivo y deductivo.
- Contrastar los aportes con el anteproyecto de la NDC.

🔁 Este proceso cuenta con dos puntos de control experto: primero en la validación de temáticas emergentes (🔹5) y luego en la validación de recomendaciones generadas (🔹10).

---
## 2. Proceso general

Cada script de esta carpeta representa el análisis de una **mesa temática** específica. Cada archivo `.cql` implementa el flujo metodológico siguiente:

### 🔹 1. Carga desde Google Sheets
Se cargan los comentarios desde una hoja pública de Google Sheets. Cada comentario contiene información sobre el diálogo, la mesa, el área metodológica y su tipo (estratégico, técnico, crítico, etc.).

```cypher
LOAD CSV WITH HEADERS FROM "https://docs.google.com/spreadsheets/d/..." AS row
CREATE (c:Comentario)
SET ...
```

### 🔹 2. Preparación de narrativa para embeddings
Se genera una narrativa por comentario, incorporando metadatos clave:
```cypher
MATCH (c:Comentario)
SET c.narrativeForEmbedding = 
  "### Comentario reescrito:\n" + c.comentarioReescrito + "\n" +
  "**Mesa temática:** " + c.mesa + "\n" +
  "**Área metodológica:** " + c.area + "\n" +
  "**Tipo de comentario:** " + c.tipoComentario + "\n"
```

Esto permite enriquecer el contexto antes de generar embeddings.

### 🔹3. Generación de embeddings (fuera de Cypher)
Una vez generadas las narrativas, estas se exportan, se procesan mediante la API de OpenAI (o similar), y se guarda la representación vectorial como propiedad embedding en cada nodo Comentario.

```cypher
MATCH (c:Comentario)
WHERE c.embedding IS NOT NULL
RETURN c.ID, c.embedding
```
### 🔹4. Identificar patrones emergentes y comunidades temáticas mediante clustering
Se calcula la similitud entre pares de comentarios usando el algoritmo gds.similarity.cosine. Luego, se aplica el algoritmo Leiden para detectar comunidades temáticas.

```cypher
CALL gds.graph.project(...)
CALL gds.similarity.cosine(...)
CALL gds.community.leiden(...)
```
### 🔹5. Identificación y validación experta de temáticas
Una vez agrupados los comentarios por similitud semántica mediante el algoritmo Leiden, se genera para cada comunidad emergente un nombre temático sugerido y su definición utilizando un modelo de lenguaje (GPT), guiado por el contexto específico de la mesa y los fragmentos relevantes del anteproyecto NDC.

Este proceso permite detectar patrones temáticos emergentes con alto nivel de coherencia interna, a partir de los comentarios más representativos en cada comunidad.
>Ejemplo: “Reconversión laboral en sectores intensivos en carbono; Se refiere a la necesidad de formar y recapacitar a trabajadores...”

⚠️ Estos nombres sugeridos no se utilizan directamente.

Los resultados son sometidos a una validación experta por parte del Comité Científico, que:

Revisa cada título y descripción propuestos.

Ajusta, fusiona o divide temáticas según su pertinencia.

Asegura claridad conceptual, solidez metodológica y alineación con las prioridades estratégicas de la NDC.

Las temáticas corregidas y validadas por los expertos se consolidan en un archivo CSV y se cargan al grafo como nodos :Tematica, cada uno con su título, descripción y vínculo con una mesa.

### 🔹6. Asignación de temáticas validadas

Posteriormente, a cada nodo :Tematica se le asigna una narrativa enriquecida, y se genera un embedding semántico. Luego cada comentario es clasificado temáticamente mediante similitud semántica entre su embedding y el embedding de cada temática validada, generando relaciones ponderadas [:RELATES_TO_THEME] con ranking.

```cypher
MERGE (r)-[:RELATES_TO_THEME]->(t)
SET rel.score = similarity, rel.rank = ...
```

📌 Resultado:
Cada comentario queda vinculado con sus tres temáticas validadas más afines, dentro de una taxonomía construida inductivamente y validada deliberativamente por expertos.

### 🔹7. Resúmenes temáticos
A continuación se compila para cada temática un conjunto de comentarios relacionados. Se generan resúmenes temáticos automáticos **de los comentarios compilados** mediante un modelo GPT, usando como contexto el nodo MesaContexto.

📌 Resultado: Cada nodo :Tematica contiene un **resumen de los comentarios** en resumenTematicoGPT, útil para análisis de resultados y la elaboración posterior de recomendaciones específicas.

### 🔹8. Generación de resumen general por mesa
A partir de los resúmenes temáticos validados y del contexto completo de la mesa (nodo MesaContexto), se genera un resumen general integrado para cada mesa de trabajo.

Este resumen consolida:
- Principales focos temáticos y propuestas recurrentes.
- Elementos transversales emergentes entre temáticas.
- Referencias explícitas a capítulos y medidas del anteproyecto NDC.

📌 Resultado: Nodo :ResumenGeneral por mesa, con contenido validado y trazable.

>📄 Resumen temático: síntesis automática por tema.
>📄 Resumen general: consolidación de todos los temas de una mesa.

### 🟢 9. Generación de recomendaciones científicas

Este módulo implementa dos enfoques metodológicos complementarios para la generación de recomendaciones orientadas al fortalecimiento del anteproyecto de la NDC 2025. Ambos enfoques utilizan modelos de lenguaje (GPT) con narrativa estructurada y contexto enriquecido, manteniendo la trazabilidad con los comentarios originales.

---

#### 🔹 9.1 Recomendaciones **bottom-up** (desde temáticas emergentes)

A partir de la clasificación temática de los comentarios mediante embeddings y validación experta:

- Se agrupan comentarios que comparten la misma temática validada.
- Se compila el contenido discursivo de cada grupo, incluyendo contexto metodológico de la mesa.
- Se genera un **resumen temático** que identifica los énfasis, preocupaciones y propuestas principales.
- Luego, se generan **dos recomendaciones por temática**, utilizando un formato argumentativo estructurado:
  - Contexto y problema detectado.
  - Evidencia científica.
  - Recomendación detallada.
  - Consideraciones de implementación.
  - Conclusión y urgencia.

📌 *Resultado:* Nodo `:Tematica` contiene propiedad `recomendacionesGPT` con dos propuestas orientadas al diseño o ajuste de políticas climáticas, directamente derivadas de los aportes recogidos.

---

#### 🔹 9.2 Recomendaciones **top-down** (comparación con la NDC)

A partir de la similitud semántica entre los comentarios enriquecidos y los fragmentos del anteproyecto de la NDC:

- Cada comentario se compara con los nodos `:TaxonomiaNDC`, usando embeddings y similitud coseno.
- Se seleccionan los **10 fragmentos más afines por comentario**, y se conservan relaciones ponderadas `[:RELATES_TO_NDC]`.
- Para cada fragmento NDC, se compilan los comentarios relacionados (máx. 5 más afines).
- Se genera una **recomendación estructurada** basada en:
  - El texto original del fragmento.
  - Los comentarios relacionados.
  - El contexto específico de la mesa temática.

📌 *Resultado:* Cada nodo `:TaxonomiaNDC` queda vinculado a su conjunto de comentarios asociados y a una recomendación generada (`recomendacionesGPT`), para identificar oportunidades de mejora del texto NDC a partir de la evidencia participativa..

---

Ambos procesos permiten enriquecer el análisis técnico con recomendaciones con base en aportes relevantes y pertinentes para la toma de decisiones climáticas. Ambos métodos entregan recomendaciones trazables y bien fundamentadas. Sin embargo, antes de su inclusión en los resultados oficiales, se someten a una revisión experta final descrita en la siguiente sección.

### 🔹 10. Validación experta de recomendaciones

Las recomendaciones generadas automáticamente mediante enfoques bottom-up y top-down no se incorporan directamente al informe final. En su lugar, pasan por un **segundo punto de control experto**, a cargo del Comité Científico de Cambio Climático.

En esta etapa, el Comité:

- Revisa críticamente cada recomendación generada por los modelos de lenguaje.
- Ajusta redacciones, complementa evidencias y evalúa su factibilidad técnica y pertinencia política.
- Prioriza las recomendaciones más relevantes de acuerdo con los objetivos del proceso participativo y los lineamientos de la NDC 2025.

📌 *Resultado:* Solo las recomendaciones validadas y consolidadas por este segundo checkpoint son consideradas para la versión final del informe científico. Esta validación fortalece la calidad metodológica, asegura coherencia estratégica y refuerza la legitimidad técnica del análisis.

