// Paso 1: Búsqueda semántica y selección de publicaciones
WITH ["**English Version** The integration of sustainable practices in aquaculture and fisheries has been shown to enhance food security and resilience to climate change.  **Versión en Español** La integración de prácticas sostenibles en acuicultura y pesca ha demostrado mejorar la seguridad alimentaria y la resiliencia al cambio climático."] AS searchTerms,


"La acuicultura y la pesca son sectores críticos en Chile, pero su relevancia no ha sido adecuadamente considerada en la seguridad alimentaria actual. Investigaciones muestran que la integración de prácticas sostenibles en acuicultura y pesca incrementan la resiliencia al cambio climático y la seguridad alimentaria. Integrar la noción de prácticas sustentables en los sectores de acuicultura y pesca, que promueve en su implementación el desarrollo de un marco regulatorio que favorezca estas prácticas." AS recomendacion

CALL apoc.ml.openai.embedding(searchTerms, $apiKey, { model: 'text-embedding-3-small' }) 
YIELD embedding
WITH embedding AS queryEmbedding, recomendacion

MATCH (r:Record)
WHERE r.embedding IS NOT NULL
WITH r, recomendacion, gds.similarity.cosine(r.embedding, queryEmbedding) AS similarity
ORDER BY similarity DESC
LIMIT 10

// Paso 2: Recolectar los campos necesarios para el análisis
WITH collect({
  title: r.title, 
  description: r.description,
  uniqueId: r.uniqueId,
  contributors: r.contributors,
  year: r.yearStart,
  journal: r.so,
  volume: r.vl
}) AS evidencias, recomendacion

// Paso 3: Construcción del texto estructurado para el prompt
WITH evidencias, recomendacion,
  apoc.text.join([e IN evidencias | 
    "**Título**: " + coalesce(e.title, "Sin título") + "\n" +
    "**Resumen**: " + coalesce(e.description, "Sin resumen") + "\n" +
    "**Autores**: " + coalesce(apoc.text.join(e.contributors, ", "), "Desconocido") + "\n" +
    "**Año**: " + coalesce(toString(e.year), "Desconocido") + "\n" +
    "**Journal**: " + coalesce(e.journal, "No especificado") + "\n" +
    "**Volumen**: " + coalesce(toString(e.volume), "N/A") + "\n" +
    "**DOI**: https://doi.org/" + coalesce(e.uniqueId, "10.xxx/xxxxx")
  ], "\n\n") AS textoEvidencias


// Paso 4: Evaluación y clasificación mediante GPT
CALL apoc.ml.openai.chat(
  [
    {
      role: 'system',
      content: "Actúa como un investigador ambiental que debe evaluar cómo distintas publicaciones respaldan una recomendación de política pública, usando evidencia científica. Tu tarea es analizar las publicaciones entregadas y clasificarlas según su nivel de vinculación con la recomendación. Además, debes generar una referencia bibliográfica en formato Harvard para cada una y entregar un enlace al DOI."
    },
    {
      role: 'user',
      content: 
        "Recomendación:\n" + recomendacion + "\n\n" +
        "Publicaciones:\n" + textoEvidencias + "\n\n" +
        "Clasifica cada publicación según los siguientes criterios:\n\n" +
        "1. **Vinculada altamente**: la publicación trata directamente sobre la temática principal de la recomendación y entrega resultados o conclusiones que la respaldan explícitamente.\n" +
        "2. **Vinculada parcialmente**: la publicación se relaciona de forma indirecta o complementaria con la recomendación, pero no la aborda como foco principal.\n" +
        "3. **No vinculada**: la publicación no tiene relación temática o empírica clara con la recomendación.\n\n" +
        "Para cada publicación, entrega lo siguiente en formato de lista:\n\n" +
        "- Título con DOI enlazado: [https://doi.org/{unique_id}](https://doi.org/{unique_id})\n" +
        "- Nivel de vinculación: (Vinculada altamente / Vinculada parcialmente / No vinculada)\n" +
        "- Breve justificación de esa clasificación.\n" +
        "- Referencia en formato Harvard (usa los campos disponibles: autores, año, título, journal, volumen, etc. Incluye el DOI solo como enlace al lado del título, no lo repitas en la referencia)."
    }
  ],
  $apiKey,
  {model: 'gpt-4o-mini'}
) YIELD value

// Paso 5: Resultado final
RETURN 
  recomendacion AS Recomendación,
  value.choices[0].message.content AS JustificacionGenerada;
