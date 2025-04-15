// Cargar comentarios reescritos (particular de cada mesa)
:auto CALL {
  LOAD CSV WITH HEADERS FROM "https://docs.google.com/spreadsheets/d/e/2PACX-1vQKgDFGZyR43fifkE7j9RwyLdojm9NAP5RbEXhmcBUT2mQvxilJSrgnSj4lvJrilVi9BaWJPMBaxYo4/pub?gid=0&single=true&output=csv" AS row
  FIELDTERMINATOR ','
  CREATE (c:Comentario)
  SET c.dialogo = row.`Dialogo Virtual o Presencial`,
      c.mesa = row.Mesa,
      c.ID = row.ID,
      c.area = row.Area,
      c.tipoComentario = row.`Tipo de comentario`,
      c.textoOriginal = row.Text,
      c.comentarioReescrito = row.`Comentario reescrito`
} IN TRANSACTIONS OF 1000 ROWS;

// Crear narrativa para cada Comentario (común para todas las mesas)
MATCH (c:Comentario)
SET c.narrativeForEmbedding = 
    "### Comentario reescrito:\n" + c.comentarioReescrito + "\n" +
    CASE WHEN c.mesa IS NOT NULL THEN "**Mesa temática:** " + c.mesa + "\n" ELSE "" END +
    CASE WHEN c.area IS NOT NULL THEN "**Área metodológica:** " + c.area + "\n" ELSE "" END +
    CASE WHEN c.tipoComentario IS NOT NULL THEN "**Tipo de comentario:** " + c.tipoComentario + "\n" ELSE "" END +
    CASE WHEN c.dialogo IS NOT NULL THEN "**Instancia de origen:** " + c.dialogo + "\n" ELSE "" END;

// Crear parámetro APIKEY
:param apiKey => 'XXX';

// Embedding para comentario (común para todas las mesas)

CALL apoc.periodic.iterate(
    "MATCH (n:Comentario) 
     WHERE n.narrativeForEmbedding IS NOT NULL AND n.embedding IS NULL 
     RETURN n, n.narrativeForEmbedding AS narrativeForEmbedding",
    "CALL apoc.ml.openai.embedding([narrativeForEmbedding], $apiKey, { model : 'text-embedding-3-small' }) 
     YIELD embedding
     SET n.embedding = embedding",
    {
        batchSize: 8,
        retries: 3,
        iterateList: true,
        parallel: true,
        params: { apiKey: $apiKey },
        config: { reportEvery: 8 }
    }
);


// Cargar taxonomía NDC desde CSV publicado (común para todas las mesas)
:auto CALL {
  LOAD CSV WITH HEADERS FROM "https://docs.google.com/spreadsheets/d/e/2PACX-1vTQKppSeriGcxmGbd2qIlEfDkcDtVpNn1eZN5reNEHE_xYOPVlD1MXH7idxT9ky5IUCXu0JCXmb3VjE/pub?gid=1875731543&single=true&output=csv" AS row
  FIELDTERMINATOR ','
  CREATE (t:TaxonomiaNDC)
  SET t.ID = row.ID,
      t.texto = row.Texto,
      t.subtitulo = row.`Subtítulo`,
      t.capitulo = row.`Capítulo`,
      t.contexto = row.Contexto
} IN TRANSACTIONS OF 1000 ROWS;

// Crear narrativa para cada nodo TaxonomiaNDC (común para todas las mesas)
MATCH (t:TaxonomiaNDC)
SET t.narrativeForEmbedding = 
    "### Texto:\n" + t.texto + "\n" +
    CASE WHEN t.capitulo IS NOT NULL THEN "**Capítulo:** " + t.capitulo + "\n" ELSE "" END +
    CASE WHEN t.subtitulo IS NOT NULL THEN "**Subtítulo:** " + t.subtitulo + "\n" ELSE "" END +
    CASE WHEN t.contexto IS NOT NULL THEN "**Contexto:** " + t.contexto + "\n" ELSE "" END;

// Crear embeddings para nodos TaxonomiaNDC a partir de narrativeForEmbedding (común para todas las mesas)
CALL apoc.periodic.iterate(
    "MATCH (n:TaxonomiaNDC) 
     WHERE n.narrativeForEmbedding IS NOT NULL AND n.embedding IS NULL 
     RETURN n, n.narrativeForEmbedding AS narrativeForEmbedding",
    "CALL apoc.ml.openai.embedding([narrativeForEmbedding], $apiKey, { model : 'text-embedding-3-small' }) 
     YIELD embedding
     SET n.embedding = embedding",
    {
        batchSize: 8,
        retries: 3,
        iterateList: true,
        parallel: true,
        params: { apiKey: $apiKey },
        config: { reportEvery: 8 }
    }
);


// Cargar nodos de contexto por mesa temática (común para todas las mesas)
:auto CALL {
  LOAD CSV WITH HEADERS FROM "https://docs.google.com/spreadsheets/d/e/2PACX-1vQgH80xR9b7i2gNejRrM0Hn5NVE4OADnUcDU19m3LFxRddByLc7y4aFRuPJQCdvb9oil8yRaursAJd9/pub?gid=1339276971&single=true&output=csv" AS row
  FIELDTERMINATOR ','
  CREATE (m:MesaContexto)
  SET m.nombre = row.Mesa,
      m.contexto = row.Contexto
} IN TRANSACTIONS OF 1000 ROWS


// Detectar temáticas a partir de similitudes entre comentarios

/// ETAPA 1: Crear relaciones entre comentarios basadas en similitud
CALL apoc.periodic.iterate(
  "
  MATCH (c1:Comentario) WHERE c1.embedding IS NOT NULL
  RETURN c1
  ",
  "
  MATCH (c2:Comentario) WHERE c2.embedding IS NOT NULL AND id(c2) > id(c1)
  WITH c1, c2, gds.similarity.cosine(c1.embedding, c2.embedding) AS similarity
  WHERE similarity > 0.8 // puedes ajustar este umbral
  MERGE (c1)-[r:SIMILAR_TO]-(c2)
  SET r.score = similarity
  ",
  {batchSize: 100, parallel: false}
);

///ETAPA 2: Crear proyección GDS sobre Comentario
CALL gds.graph.project(
  'commentSimilarityGraph',
  'Comentario',
  {
    SIMILAR_TO: {
      type: 'SIMILAR_TO',
      orientation: 'UNDIRECTED',
      properties: ['score']
    }
  }
);

/// ETAPA 3: Detectar comunidades emergentes con Leiden y comunidades intermedias

CALL gds.leiden.write('commentSimilarityGraph', {
  writeProperty: 'comunidadEmergente',
  includeIntermediateCommunities: true
});


/// ETAPA 4: Revisar comunidades intermedias y finales

// Ver comentarios agrupados por nivel
MATCH (c:Comentario)
WHERE c.comunidadEmergente IS NOT NULL
WITH c.comunidadEmergente[0] AS comunidad, collect(c.comentarioReescrito) AS comentarios
RETURN comunidad AS Comunidad, comentarios
ORDER BY size(comentarios) DESC
LIMIT 20;

/// ETAPA 5: Nombrar automáticamente la comunidad usando nivel 0 de Leiden (cambiar según revisión de cantidad de comunidades)

MATCH (c:Comentario)
WHERE c.comunidadEmergente IS NOT NULL
WITH c.comunidadEmergente[0] AS comunidad, collect("- " + c.comentarioReescrito) AS lista
WITH comunidad, apoc.text.join(lista, "\n") AS texto

CALL apoc.ml.openai.chat(
  [
    {
      role: 'system',
      content: "Actúa como un investigador experto en análisis cualitativo y políticas públicas en el contexto de cambio climático. Tu tarea es asignar un **nombre temático claro y conciso** y una definición a este conjunto de comentarios reescritos.\n\n Contexto:\nResumen detallado de lo trabajado en la mesa y el detalle del documento NDC referido a esta mesa

La Transición Socioecológica Justa se refiere a un proceso que busca la transformación de la sociedad hacia un modelo resiliente y equitativo, capaz de enfrentar las crisis sociales, ecológicas y climáticas. Este proceso reconoce la estrecha interrelación entre los sistemas sociales y ecológicos y la manera en que los impactos del cambio climático exacerban las desigualdades estructurales preexistentes en el territorio y entre los grupos sociales, afectando de manera desproporcionada a comunidades vulnerables, pueblos indígenas, mujeres, niños y personas mayores.
La 'Transición Socioecológica Justa' implica un reenfoque del desarrollo económico que aborda las inequidades sociales, económicas y ambientales de un país, buscando resguardar los ecosistemas y el bienestar de las personas. Es un proceso que se lleva a cabo a través del diálogo social y el empoderamiento colectivo, y requiere la incorporación de enfoques de género, intercultural y territorial en todas las iniciativas de adaptación y mitigación al cambio climático, con el objetivo de disminuir y superar las desigualdades.
Este concepto abarca componentes sociales, económicos, institucionales y ecológicos. En el marco de este proceso, es vital resguardar el trabajo decente, la seguridad laboral y el nivel de vida, asegurando que las acciones de adaptación y mitigación protejan el empleo y/o ayuden a su reconversión, fomentando la transformación sostenible del sistema productivo.
La gestión del cambio climático, en el contexto de una 'Transición Socioecológica Justa', debe considerar una justa asignación de cargas, costos y beneficios, protegiendo a los ecosistemas vulnerables y resguardando los derechos humanos, el derecho al desarrollo de las generaciones presentes y futuras, y la salud y el bienestar integral de la población. Además, busca priorizar la eliminación de las brechas sociales preexistentes y las cargas ambientales históricas.
La implementación de la Estrategia Nacional de Transición Socioecológica Justa (ENTSEJ) 2025-2035 busca guiar a Chile hacia una sociedad sostenible, baja en carbono, consciente con el medio ambiente y resiliente, asegurando la aplicación de los enfoques de derechos humanos, enfoque territorial, la igualdad de género y el trabajo decente en la transición. Sin embargo, se ha señalado que el enfoque actual podría estar extremadamente centrado en lo laboral, dejando de lado otros elementos importantes como el capital ambiental y cultural de los territorios y la identidad comunitaria. También se ha destacado la importancia de considerar un sistema de gobernanza que se haga cargo de múltiples dimensiones como el desarrollo de oportunidades económicas, desarrollo humano, protección ambiental, justicia climática, gobernanza democrática y buena administración.

Contribución en Transición Socioecológica Justa: 
- PTSEJ1) Implementar la Estrategia Nacional de Transición Socioecológica Justa 2025-2035 (ENTSEJ). Esta estrategia busca guiar a Chile hacia una sociedad sostenible, baja en carbono, consciente del medio ambiente y resiliente, abordando la pérdida de biodiversidad, el cambio climático y la contaminación, y asegurando la aplicación de enfoques de derechos humanos, territorial, igualdad de género y trabajo decente. 
- PTSEJ2) A 2028, Chile contará con una metodología de medición de variables socioeconómicas que permita gestionar, a nivel sectorial, la transición laboral justa de los empleos impactados por el cambio climático. El objetivo es desarrollar herramientas para comprender y gestionar los efectos del cambio climático en el empleo y facilitar una transición equitativa para los trabajadores en los distintos sectores. 
- PTSEJ3) A 2035, cada Plan Sectorial de Mitigación o de Adaptación al Cambio Climático habrá implementado al menos una medida que contribuya a la protección del empleo y/o a la reconversión laboral en actividades productivas vulnerables al cambio climático, o que sean sujetas de medidas de mitigación de GEI. Esto asegura que los planes sectoriales consideren activamente la protección y la reconversión laboral en sectores afectados por el cambio climático o las medidas para mitigarlo. 
- PTSEJ4) A 2029, los informes de evaluación de los instrumentos de gestión de cambio climático medirán los costos y beneficios económicos, ambientales y sociales de las políticas climáticas, integrando indicadores de salud, empleo, equidad de género y reducción de la pobreza, entre otros. Asimismo, incorporarán información desagregada por grupos vulnerables, de acuerdo con una metodología estandarizada que se pondrá a disposición a más tardar el año 2027. Se busca una evaluación integral de las políticas climáticas, considerando diversos aspectos socioeconómicos y su impacto en grupos vulnerables, utilizando una metodología coherente. 
- PTSEJ5) A 2026, los Planes Comunales de Cambio Climático de los territorios en transición definidos en la ETSEJ, incluirán los lineamientos de la ETSEJ. Esto busca alinear la planificación climática a nivel local con la Estrategia Nacional de Transición Socioecológica Justa en los territorios que se identifiquen como prioritarios para esta transición.
  
\n\n### Instrucción:\nCon base en el contenido del conjunto de comentarios, identifica el **tema principal** que los articula. El nombre asignado debe:\n- Ser **específico**, **relevante** y **distinto**.\n- Ser **útil para agrupar recomendaciones de política pública climática**.\n- Tener **máximo 10 palabras** y no repetir expresiones genéricas como 'medio ambiente' o 'territorio'.
\n\n Devuelve el título de la temática y su descripción, en base estrictamente a los comentarios entregados. Solo debe haber un nombre de temática y una definición por este conjunto de comentarios. La salida debe estar en el formato:  
Título Temática; Descripción

Ejemplos:  
1. Reconversiones laborales y capacitación en la transición climática; Se refiere a la necesidad de formar y recapacitar a trabajadores para enfrentar los cambios estructurales que implica la descarbonización, asegurando empleos dignos y sostenibles en nuevas áreas productivas.  
2. Calidad y coherencia en los instrumentos subnacionales; Aborda la preocupación por la repetición y escasa efectividad de los planes regionales y comunales, destacando la urgencia de fortalecer su diseño, pertinencia territorial y base empírica."
    },
    {
      role: 'user',
      content: texto
    }
  ],
  $apiKey,
  {model: 'gpt-4o-mini'}
) YIELD value

RETURN 
  comunidad AS comunidadID, 
  value.choices[0].message.content AS nombreTematicaSugerida, 
  texto AS comentariosUtilizados;

// Cargar temáticas de la mesa con descripción (particular de cada mesa)
:auto CALL {
  LOAD CSV WITH HEADERS FROM "https://docs.google.com/spreadsheets/d/e/2PACX-1vQKgDFGZyR43fifkE7j9RwyLdojm9NAP5RbEXhmcBUT2mQvxilJSrgnSj4lvJrilVi9BaWJPMBaxYo4/pub?gid=1821860081&single=true&output=csv" AS row
  FIELDTERMINATOR ','
  CREATE (t:Tematica)
  SET t.titulo = row.`Título Temática`,
      t.descripcion = row.Descripción,
      t.mesa = row.Mesa
} IN TRANSACTIONS OF 1000 ROWS;


// Crear narrativa para cada Tematica (particular de cada mesa)
MATCH (t:Tematica)
SET t.narrativeForEmbedding = 
    "### Título de la temática:\n" + t.titulo + "\n" +
    CASE WHEN t.descripcion IS NOT NULL THEN "**Descripción:** " + t.descripcion + "\n" ELSE "" END +
    CASE WHEN t.subcapitulo IS NOT NULL THEN "**Subcapítulo NDC relacionado:** " + t.subcapitulo + "\n" ELSE "" END;


// Embedding para Temática (común para todas las mesas)

CALL apoc.periodic.iterate(
    "MATCH (n:Tematica) 
     WHERE n.narrativeForEmbedding IS NOT NULL AND n.embedding IS NULL 
     RETURN n, n.narrativeForEmbedding AS narrativeForEmbedding",
    "CALL apoc.ml.openai.embedding([narrativeForEmbedding], $apiKey, { model : 'text-embedding-3-small' }) 
     YIELD embedding
     SET n.embedding = embedding",
    {
        batchSize: 8,
        retries: 3,
        iterateList: true,
        parallel: true,
        params: { apiKey: $apiKey },
        config: { reportEvery: 8 }
    }
);


// Comparar comentarios con temáticas (común para todas las mesas)
CALL apoc.periodic.iterate(
  "
  MATCH (r:Comentario) 
  WHERE r.embedding IS NOT NULL 
  RETURN r
  ",
  "
  MATCH (t:Tematica) 
  WHERE t.embedding IS NOT NULL
  WITH r, t, gds.similarity.cosine(r.embedding, t.embedding) AS similarity
  WHERE similarity IS NOT NULL
  WITH r, t, similarity
  ORDER BY similarity DESC
  WITH r, collect({tematica: t, similarity: similarity}) AS top_tematics
  UNWIND top_tematics[0..3] AS thematic_info
  WITH r, thematic_info.tematica AS t, thematic_info.similarity AS similarity
  MERGE (r)-[rel:RELATES_TO_THEME]->(t)
  SET rel.score = similarity
  ",
  {batchSize: 100, parallel: false}
);

// Guardar ranking (común para todas las mesas)

CALL apoc.periodic.iterate(
  "
  MATCH (r:Comentario)-[rel:RELATES_TO_THEME]->(:Tematica)
  RETURN DISTINCT r
  ",
  "
  MATCH (r)-[rel:RELATES_TO_THEME]->(:Tematica)
  WITH r, rel
  ORDER BY rel.score DESC
  WITH r, collect(rel) AS rels
  UNWIND range(0, size(rels)-1) AS idx
  WITH rels[idx] AS rel, idx + 1 AS rank
  SET rel.rank = rank
  ",
  {batchSize: 100, parallel: false}
);

// Tabla de temáticas afines a cada comentario (común para todas las mesas)
MATCH (c:Comentario)-[r:RELATES_TO_THEME]->(t:Tematica)
WITH c, t.titulo AS tematica, r.score AS score
ORDER BY c.comentarioReescrito, score DESC
WITH c, collect(tematica)[0..3] AS top_tematics, collect(score)[0..3] AS top_scores
RETURN 
  c.ID AS `ID Comentario`,
  c.mesa AS Mesa,
  c.area AS Area,
  c.tipoComentario AS `Tipo de comentario`,
  c.comentarioReescrito AS `Comentario reescrito`,
  top_tematics[0] AS `Temática asignada 1`,
  top_scores[0] AS scoret1,
  top_tematics[1] AS `Temática asignada 2`,
  top_scores[1] AS scoret2,
  top_tematics[2] AS `Temática asignada 3`,
  top_scores[2] AS scoret3


// compilar comentarios como una propiedad de temática, cada vez que dicha temática fue rank 1 en ese comentario (común para todas las mesas)

MATCH (t:Tematica)<-[r:RELATES_TO_THEME]-(c:Comentario)
WHERE r.rank = 1
WITH t, collect("- " + c.comentarioReescrito) AS comentariosRank1
SET t.comentariosCompilados = apoc.text.join(comentariosRank1, "\n")
RETURN t.titulo, t.comentariosCompilados


/// Método TopDown desde los textos//////

// Crear narrativa enriquecida (comentario más temática principal) sin sobrescribir la original (común para todas las mesas)
MATCH (c:Comentario)-[r:RELATES_TO_THEME]->(t:Tematica)
WHERE r.rank = 1
SET c.narrativeForEmbeddingEnriched = 
    "### Comentario reescrito:\n" + c.comentarioReescrito + "\n" +
    CASE WHEN c.mesa IS NOT NULL THEN "**Mesa temática:** " + c.mesa + "\n" ELSE "" END +
    CASE WHEN c.area IS NOT NULL THEN "**Área metodológica:** " + c.area + "\n" ELSE "" END +
    CASE WHEN c.tipoComentario IS NOT NULL THEN "**Tipo de comentario:** " + c.tipoComentario + "\n" ELSE "" END +
    CASE WHEN c.dialogo IS NOT NULL THEN "**Instancia de origen:** " + c.dialogo + "\n" ELSE "" END +
    "\n---\n" +
    "### Título de la temática relacionada:\n" + t.titulo + "\n" +
    CASE WHEN t.descripcion IS NOT NULL THEN "**Descripción:** " + t.descripcion + "\n" ELSE "" END +
    CASE WHEN t.subcapitulo IS NOT NULL THEN "**Subcapítulo NDC relacionado:** " + t.subcapitulo + "\n" ELSE "" END;


// Crear embeddings desde narrativa enriquecida en Comentario (común para todas las mesas)
CALL apoc.periodic.iterate(
    "MATCH (n:Comentario) 
     WHERE n.narrativeForEmbeddingEnriched IS NOT NULL AND n.embeddingEnriched IS NULL 
     RETURN n, n.narrativeForEmbeddingEnriched AS narrative",
    "CALL apoc.ml.openai.embedding([narrative], $apiKey, { model : 'text-embedding-3-small' }) 
     YIELD embedding
     SET n.embeddingEnriched = embedding",
    {
        batchSize: 8,
        retries: 3,
        iterateList: true,
        parallel: true,
        params: { apiKey: $apiKey },
        config: { reportEvery: 8 }
    }
);


// Comparar comentarios enriquecidos con taxonomía NDC (común para todas las mesas)
CALL apoc.periodic.iterate(
  "
  MATCH (r:Comentario) 
  WHERE r.embeddingEnriched IS NOT NULL 
  RETURN r
  ",
  "
  MATCH (t:TaxonomiaNDC) 
  WHERE t.embedding IS NOT NULL
  WITH r, t, gds.similarity.cosine(r.embeddingEnriched, t.embedding) AS similarity
  WHERE similarity IS NOT NULL
  WITH r, t, similarity
  ORDER BY similarity DESC
  WITH r, collect({taxonomia: t, similarity: similarity})[0..10] AS top_taxonomias
  UNWIND top_taxonomias AS taxo_info
  WITH r, taxo_info.taxonomia AS t, taxo_info.similarity AS similarity
  MERGE (r)-[rel:RELATES_TO_NDC]->(t)
  SET rel.score = similarity
  ",
  {batchSize: 100, parallel: false}
);

// Asignar ranking 1–10 a las relaciones con TaxonomiaNDC (común para todas las mesas)
CALL apoc.periodic.iterate(
  "
  MATCH (r:Comentario)-[rel:RELATES_TO_NDC]->(:TaxonomiaNDC)
  RETURN DISTINCT r
  ",
  "
  MATCH (r)-[rel:RELATES_TO_NDC]->(:TaxonomiaNDC)
  WITH r, rel
  ORDER BY rel.score DESC
  WITH r, collect(rel) AS rels
  UNWIND range(0, size(rels)-1) AS idx
  WITH rels[idx] AS rel, idx + 1 AS rank
  SET rel.rank = rank
  ",
  {batchSize: 100, parallel: false}
);


// Tabla: Texto NDC, capítulo y top 10 comentarios relacionados (común para todas las mesas)
MATCH (t:TaxonomiaNDC)<-[r:RELATES_TO_NDC]-(c:Comentario)
WITH t, c, r
ORDER BY t.texto, r.score DESC
WITH t, collect(c.comentarioReescrito)[0..10] AS comentarios, collect(r.score)[0..10] AS scores
RETURN 
  t.ID AS `ID NDC`,
  t.capitulo AS `Capítulo NDC`,
  t.texto AS `Texto NDC`,
  comentarios[0] AS `Comentario 1`, scores[0] AS `Score 1`,
  comentarios[1] AS `Comentario 2`, scores[1] AS `Score 2`,
  comentarios[2] AS `Comentario 3`, scores[2] AS `Score 3`,
  comentarios[3] AS `Comentario 4`, scores[3] AS `Score 4`,
  comentarios[4] AS `Comentario 5`, scores[4] AS `Score 5`,
  comentarios[5] AS `Comentario 6`, scores[5] AS `Score 6`,
  comentarios[6] AS `Comentario 7`, scores[6] AS `Score 7`,
  comentarios[7] AS `Comentario 8`, scores[7] AS `Score 8`,
  comentarios[8] AS `Comentario 9`, scores[8] AS `Score 9`,
  comentarios[9] AS `Comentario 10`, scores[9] AS `Score 10`;


// Compilar solo los 10 comentarios más afines por cada nodo TaxonomiaNDC (común para todas las mesas)
MATCH (t:TaxonomiaNDC)<-[r:RELATES_TO_NDC]-(c:Comentario)
WHERE r.rank <= 10
WITH t, collect("- " + c.comentarioReescrito) AS comentarios
SET t.comentariosAsociados = apoc.text.join(comentarios, "\n")
RETURN t.ID AS `ID NDC`, size(comentarios) AS cantidadComentarios;

// Visualización estrella para mostrar solo los 10 comentarios más afines por cada texto de TaxonomiaNDC (común para todas las mesas)
MATCH (t:TaxonomiaNDC)<-[r:RELATES_TO_NDC]-(c:Comentario)
WITH t, r, c
ORDER BY t.ID, r.score DESC
WITH t, collect({c: c, r: r})[0..10] AS topRelacionados
UNWIND topRelacionados AS relData
WITH t, relData.c AS c, relData.r AS r
RETURN t, r, c
LIMIT 100;


// Explicación técnica del proceso de clasificación y filtrado (común para todas las mesas)
En el proceso de clasificación semántica de los comentarios del proceso participativo de la NDC 2025, cada comentario enriquecido se compara con todas las entradas de la taxonomía NDC mediante la métrica de similitud coseno entre embeddings.

Para cada comentario, se seleccionan únicamente las 10 taxonomías más similares, las cuales se almacenan junto con su valor de similitud (score) a través de la relación RELATES_TO_NDC. Este enfoque garantiza que cada comentario quede vinculado exclusivamente con sus top 10 coincidencias más cercanas dentro de la taxonomía, priorizando la relevancia relativa por sobre un umbral absoluto de similitud.

Posteriormente, al construir la tabla resumen desde el punto de vista de las taxonomías, se muestran los comentarios que han sido clasificados como altamente relacionados con cada entrada. Como resultado, algunas taxonomías tienen múltiples comentarios asociados, mientras que otras pueden tener solo uno o ninguno, dependiendo de cuán frecuentemente fueron seleccionadas como top 10 por los comentarios. Esto explica por qué la cantidad de comentarios por taxonomía es variable y, en ningún caso, excede las 10 asociaciones.



// Crear resúmenes temáticos para una mesa específica (definida manualmente) (a partir de los comentarios en primer, segundo y tercer lugar)
WITH "Mesa 1 - Transición Socioecológica Justa" AS nombreMesa
MATCH (m:MesaContexto {nombre: nombreMesa})
WITH m, nombreMesa

MATCH (t:Tematica)
WHERE t.mesa = nombreMesa

// Filtrar solo los comentarios donde esta temática fue la más relevante (rank = 1)
MATCH (t)<-[r:RELATES_TO_THEME]-(c:Comentario)
WHERE r.rank IN [1, 2]
WITH t, m, collect("- " + c.comentarioReescrito) AS comentariosFiltrados
WHERE size(comentariosFiltrados) > 0

WITH t, m, apoc.text.join(comentariosFiltrados, "\n") AS textoComentarios

CALL apoc.ml.openai.chat(
  [
    {
      role: 'system',
      content: "Actúa como un investigador en ciencias sociales especializado en sistematización de talleres participativos. Tu tarea es redactar un resumen temático a partir de un conjunto de comentarios reescritos generados en el proceso participativo de la NDC 2025 de Chile.\n\nCada conjunto corresponde a una única temática. A partir de los comentarios entregados:\n\n1. Describe brevemente el foco principal de los comentarios dentro de esta temática.\n2. Resume los énfasis, preocupaciones o propuestas expresadas por las personas participantes.\n3. Finaliza con una observación científica útil para la formulación de recomendaciones de política pública climática, que haga referencia a la NDC.\n\nToma en cuenta el siguiente contexto general de la mesa:\n\"" + m.contexto + "\"\n\nFormato de salida:\nTemática: [nombre]; Resumen: [texto único, sin saltos de línea]"
    },
    {
      role: 'user',
      content: "Temática: " + t.titulo + "; Comentarios: " + apoc.text.replace(textoComentarios, "\n", " ")
    }
  ],
  $apiKey,
  {model: 'gpt-4o-mini'}
) YIELD value

SET t.resumenTematicoGPT = value.choices[0].message.content

RETURN 
  t.titulo AS Temática,
  t.resumenTematicoGPT AS Resumen,
  textoComentarios AS `Comentarios utilizados`;


// Crear o actualizar resumen general para una mesa, usando contexto y resúmenes temáticos
WITH "Mesa 1 - Transición Socioecológica Justa" AS nombreMesa

MATCH (m:MesaContexto {nombre: nombreMesa})
WITH m, nombreMesa

MATCH (t:Tematica)
WHERE t.resumenTematicoGPT IS NOT NULL AND t.mesa = nombreMesa
WITH m, nombreMesa, collect(t.resumenTematicoGPT) AS resumenesTematicos

WITH m, nombreMesa, apoc.text.join(resumenesTematicos, " ") AS textoCompleto

CALL apoc.ml.openai.chat(
  [
    {
      role: 'system',
      content: "Actúa como un investigador en ciencias sociales especializado en sistematización de talleres participativos. Tu tarea es redactar un resumen general a partir de resúmenes temáticos ya generados en el marco del proceso participativo de la NDC 2025 de Chile.\n\nAntes de comenzar, considera cuidadosamente este contexto:\n\n\"" + m.contexto + "\"\n\nAhora, con base en los resúmenes temáticos y este contexto genera un resumen breve que tenga las siguientes secciones:\n\n1. Integra los principales focos temáticos y explícalos.\n2. Señala elementos transversales o emergentes comunes a las temáticas tratadas.\n3. Relaciona y menciona explícitamente los resumenes con los capítulos y medidas del anteproyecto de la NDC que te acabo de entregar. Usa un tono académico, objetivo, pragmático y siempre señala referencias a la NDC en términos de capítulos, subcapítulos y medidas relacionadas. No ocupes información adicional a la que se te provee.\n\nFormato de salida:\n---\n**Resumen de la mesa:**\n[párrafo integrado que articula los focos temáticos y elementos clave para la sistematización posterior]\n---"
    },
    {
      role: 'user',
      content: "Resúmenes temáticos: " + apoc.text.replace(textoCompleto, "\n", " ")
    }
  ],
  $apiKey,
  {model: 'gpt-4o-mini'}
) YIELD value

MERGE (r:ResumenGeneral {subcapitulo: nombreMesa})
SET r.texto = value.choices[0].message.content,
    r.actualizado = datetime()

RETURN 
  nombreMesa AS `Mesa`,
  r.texto AS `Resumen generado`,
  r.actualizado AS `Fecha actualización`;

// ETAPA 6 - Generar recomendaciones estructuradas por temática con contexto de la mesa
WITH "Mesa 1 - Transición Socioecológica Justa" AS nombreMesa

MATCH (t:Tematica)
WHERE t.mesa = nombreMesa

MATCH (m:MesaContexto {nombre: nombreMesa})
WHERE m.contexto IS NOT NULL

// Traer solo comentarios donde esta temática fue rank 1
MATCH (t)<-[r:RELATES_TO_THEME]-(c:Comentario)
WHERE r.rank IN [1, 2]

WITH t, m, collect("- " + c.comentarioReescrito) AS comentariosFiltrados
WHERE size(comentariosFiltrados) > 0

WITH t, m, apoc.text.join(comentariosFiltrados, "\n") AS textoComentarios

CALL apoc.ml.openai.chat(
  [
    {
      role: 'system',
      content: "Actúa como un investigador en ciencias sociales especializado en sistematización de talleres participativos. Tu tarea es analizar un conjunto de comentarios reescritos agrupados por similitud temática y generar **exactamente 2 recomendaciones científicas**, orientadas a mejorar o complementar el anteproyecto de la NDC 2025 de Chile.\n\n---\n### Contexto:\n" + m.contexto + "\n\n### Instrucción:\nCada recomendación debe derivarse del contenido de los comentarios y el contexto. No generes una recomendación por cada comentario, sino que agrupa ideas afines.\n\nCada recomendación debe seguir esta estructura exacta:\n\n[Context & Problem Statement] → [Scientific Evidence Summary] → [Detailed Recommendations] → [Implementation Considerations] → [Conclusion & Urgency]\n\n- Cada recomendación debe estar escrita **en una sola línea**, sin saltos de línea ni subtítulos internos.\n- **Separa las dos recomendaciones con punto y coma (;)**, y no agregues ningún texto adicional fuera de ellas.\n- No repitas los comentarios ni copies secciones del contexto.\n\nFormato de salida:\nUna línea por recomendación, separadas por punto y coma. Ejemplo:\n\nIndicadores diferenciados de justicia climática: [Context] La NDC actual no incluye indicadores con sensibilidad territorial… → [Evidence] Estudios de gobernanza… → [Recommendation] Incluir un sistema nacional de… → [Implementation] Definir antes de 2027… → [Conclusion] Esto es clave para la transición justa; Coherencia en planes subnacionales: [Context] Se identifican inconsistencias… → [Evidence] Revisión de casos… → [Recommendation] Unificar lineamientos… → [Implementation] Incluir monitoreo… → [Conclusion] Mejora la eficacia territorial."
    },
    {
      role: 'user',
      content: "Temática: " + t.titulo + "\nComentarios:\n" + apoc.text.replace(textoComentarios, "\n", " ")
    }
  ],
  $apiKey,
  {model: 'gpt-4o-mini'}
) YIELD value

SET t.recomendacionesGPT = value.choices[0].message.content

RETURN 
  t.titulo AS `Temática`,
  t.recomendacionesGPT AS `Recomendaciones generadas`,
  textoComentarios AS `Comentarios utilizados`;



// Etapa 7 - Recomendaciones con comentarios y contexto definidos manualmente
WITH "Mesa 1 - Transición Socioecológica Justa" AS nombreMesa
MATCH (t:TaxonomiaNDC)<-[r:RELATES_TO_NDC]-(c:Comentario),
      (m:MesaContexto {nombre: nombreMesa})
WHERE r.score IS NOT NULL
WITH t, m, c, r
ORDER BY t.ID, r.score DESC
WITH t, m, collect(c)[0..5] AS topComentarios
WHERE size(topComentarios) > 0

WITH t, m, topComentarios, 
     apoc.text.join([x IN topComentarios | x.comentarioReescrito], "\n") AS comentariosConcatenados

CALL apoc.ml.openai.chat(
  [
    {
      role: 'system',
      content: "Actúa como un investigador en ciencias sociales especializado en sistematización de talleres participativos.\n\n" +
               "### Contexto:\n\"" + m.contexto + "\"\n\n" +
               "Tu tarea es analizar un conjunto de comentarios reescritos que se han identificado como altamente relacionados con un fragmento específico de la NDC 2025 de Chile. A partir de este conjunto de comentarios y del contenido del fragmento de la NDC, debes generar una sola recomendación estructurada orientada a optimizar y complementar el fragmento de la NDC que se quiere comentar.\n\n" +
               "### Fragmento de la NDC:\n\"" + t.texto + "\"\n\n" +
               "Cada recomendación debe seguir esta estructura:\n\n" +
               "[Context & Problem Statement] → [Scientific Evidence Summary] → [Detailed Recommendations] → [Implementation Considerations] → [Conclusion & Urgency]\n\n" +
               "[Context & Problem Statement] → Presenta brevemente el problema o desafío de política pública que se busca abordar. Explica por qué es relevante en el marco de la NDC y qué brecha, riesgo o necesidad concreta refleja.\n\n" +
               "[Scientific Evidence Summary] → Resume los hallazgos, argumentos o conocimientos científicos disponibles que fundamentan la recomendación. Puede incluir evidencias empíricas, estudios, marcos conceptuales o aprendizajes del proceso participativo.\n\n" +
               "[Detailed Recommendations] → Expone la propuesta específica que se sugiere implementar. Debe ser clara, factible y orientada a resultados, incluyendo el qué, cómo y para qué de la acción recomendada.\n\n" +
               "[Implementation Considerations] → Describe los aspectos clave para llevar a cabo la recomendación, como recursos necesarios, actores involucrados, plazos tentativos o posibles dificultades.\n\n" +
               "[Conclusion & Urgency] → Reafirma la importancia de la acción propuesta y su contribución al logro de los objetivos climáticos. Puede destacar beneficios esperados y los riesgos de no actuar a tiempo.\n\n" +
               "No generes más de 1 recomendación por fragmento de la NDC. No repitas comentarios individuales ni copies el texto de la NDC. La recomendación debe basarse en el contenido combinado de los comentarios y estar orientada a abordar el fragmento de la NDC presentado.\n\n" +
               "### Formato de salida:\nUna recomendación estructurada. Debe estar redactada en una sola línea de texto."
    },
    {
      role: 'user',
      content: "Comentarios:\n" + comentariosConcatenados
    }
  ],
  $apiKey,
  {model: 'gpt-4o-mini'}
) YIELD value

SET t.recomendacionesGPT = value.choices[0].message.content
RETURN 
  t.ID AS `ID NDC`,
  t.capitulo AS `Capítulo`,
  t.subtitulo AS `Subcapítulo`,
  t.texto AS `Texto NDC`,
  comentariosConcatenados AS `Comentarios utilizados`,
  t.recomendacionesGPT AS `Recomendación generada`;

// Paso 7_B - Mostrar tabla final con subcapítulo incluido
WITH "Mesa 1 - Transición Socioecológica Justa" AS nombreMesa
MATCH (ndc:TaxonomiaNDC)<-[r:RELATES_TO_NDC]-(c:Comentario),
      (m:MesaContexto {nombre: nombreMesa})
WHERE r.score IS NOT NULL
WITH ndc, r, c
ORDER BY ndc.ID, r.score DESC
WITH ndc, collect("- " + c.comentarioReescrito)[0..5] AS comentariosTop5
WHERE size(comentariosTop5) > 0

RETURN 
  ndc.ID AS `ID NDC`,
  ndc.capitulo AS `Capítulo`,
  ndc.subtitulo AS `Subcapítulo`,
  ndc.texto AS `Texto NDC`,
  apoc.text.join(comentariosTop5, "\n") AS `Top 5 comentarios utilizados`,
  ndc.recomendacionesGPT AS `Recomendación generada`
ORDER BY ndc.ID
