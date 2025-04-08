// ETAPA 0: Cargar recomendaciones desde CSV (exportado desde tu script en Python)
:auto CALL {
  LOAD CSV WITH HEADERS FROM "https://docs.google.com/spreadsheets/d/e/2PACX-1vR_QggMecTxXwM-zJB9mRyNbxvVPO8dzC1Pg-r-9ZpMn67uh6jOrIy9PpY5ZhGYNH_Y2iFivZIVsyVS/pub?gid=0&single=true&output=csv" AS row
  FIELDTERMINATOR ','

  MERGE (c:Recomendacion {id: row.ID})
  SET 
    c.mesa = row.Mesa,
    c.objetivo = row.`Objeto de la recomendación`,
    c.recomendacionOriginal = row.Recomendación,
    c.searchTerms = row.searchTerms_Neo4J
} IN TRANSACTIONS OF 1000 ROWS;

//ETAPA 1: Crear los embeddings para búsqueda semántica
CALL apoc.periodic.iterate(
  "
  MATCH (r:Recomendacion)
  WHERE r.recomendacionOriginal IS NOT NULL AND r.embedding IS NULL
  RETURN r, r.recomendacionOriginal AS textoEmbedding
  ",
  "
  CALL apoc.ml.openai.embedding([textoEmbedding], $apiKey, { model : 'text-embedding-3-small' }) 
  YIELD embedding
  SET r.embedding = embedding
  ",
  {
    batchSize: 8,
    retries: 3,
    iterateList: true,
    parallel: true,
    params: { apiKey: $apiKey },
    config: { reportEvery: 8 }
  }
);

//ETAPA 2: Crear relaciones por similitud entre embeddings
CALL apoc.periodic.iterate(
  "
  MATCH (r1:Recomendacion) WHERE r1.embedding IS NOT NULL
  RETURN r1
  ",
  "
  MATCH (r2:Recomendacion) WHERE r2.embedding IS NOT NULL AND id(r2) > id(r1)
  WITH r1, r2, gds.similarity.cosine(r1.embedding, r2.embedding) AS similarity
  WHERE similarity > 0.85
  MERGE (r1)-[s:SIMILAR_TO]-(r2)
  SET s.score = similarity
  ",
  {batchSize: 100, parallel: false}
);

//ETAPA 3: Proyección GDS y detección de comunidades Leiden
CALL gds.graph.project(
  'recomendacionesGraph',
  'Recomendacion',
  {
    SIMILAR_TO: {
      type: 'SIMILAR_TO',
      orientation: 'UNDIRECTED',
      properties: ['score']
    }
  }
);

CALL gds.leiden.write('recomendacionesGraph', {
  writeProperty: 'comunidadEmergente',
  includeIntermediateCommunities: true
});

//ETAPA 4: Nombrar automáticamente comunidades (nivel 0 de Leiden)
MATCH (r:Recomendacion)
WHERE r.comunidadEmergente IS NOT NULL
WITH r.comunidadEmergente[0] AS comunidad, collect("- " + r.searchTerms) AS lista
WITH comunidad, apoc.text.join(lista, "\n") AS texto

CALL apoc.ml.openai.chat(
  [
    {
      role: 'system',
      content: "Actúa como un investigador experto en análisis cualitativo y políticas públicas en el contexto de cambio climático. Tu tarea es reescribir este conjunto de recomendaciones en una sola recomendación, respetando la estructura que contienen y manteniendo todos los temas que abordan.\n\n
La recomendación debe ser:\n
- **específico**, **relevante** y **distinto**.\n
- **Efectiva para agrupar y mantener las ideas**.\n
- Tener **máximo 1 párrafo**.\n\n
Formato de salida:\n
Recomendación reescrita"
    },
    {
      role: 'user',
      content: texto
    }
  ],
  '<tu-api-key>',
  {model: 'gpt-4o-mini'}
) YIELD value

MERGE (n:ComunidadEmergente {id: comunidad})
SET n.tituloYdescripcion = value.choices[0].message.content;

//ETAPA 5: Visualizar comunidades temáticas
MATCH (r:Recomendacion)
CALL {
  WITH r
  MATCH (r)-[s:SIMILAR_TO]-(otro:Recomendacion)
  WHERE r.id <> otro.id
  RETURN 
    collect(otro.recomendacionOriginal)[0..5] AS similares,
    collect(otro.mesa)[0..5] AS mesas,
    collect(s.score)[0..5] AS scores
}
RETURN 
  r.id AS ID,
  r.mesa AS Mesa,
  r.recomendacionOriginal AS Comentario,
  similares[0] AS Similar_1,
  mesas[0] AS Mesa_1,
  scores[0] AS Score_1,
  similares[1] AS Similar_2,
  mesas[1] AS Mesa_2,
  scores[1] AS Score_2,
  similares[2] AS Similar_3,
  mesas[2] AS Mesa_3,
  scores[2] AS Score_3,
  similares[3] AS Similar_4,
  mesas[3] AS Mesa_4,
  scores[3] AS Score_4,
  similares[4] AS Similar_5,
  mesas[4] AS Mesa_5,
  scores[4] AS Score_5
ORDER BY ID;

//Código para comparar recomendaciones entre sí y guardar top 10
CALL apoc.periodic.iterate(
  "
  MATCH (r1:Recomendacion) 
  WHERE r1.embedding IS NOT NULL
  RETURN r1
  ",
  "
  MATCH (r2:Recomendacion) 
  WHERE r2.embedding IS NOT NULL AND r1 <> r2
  WITH r1, r2, gds.similarity.cosine(r1.embedding, r2.embedding) AS similarity
  WHERE similarity IS NOT NULL
  WITH r1, collect({recom: r2, similarity: similarity})[0..10] AS top_similars
  UNWIND top_similars AS sim
  WITH r1, sim.recom AS r2, sim.similarity AS similarity
  MERGE (r1)-[rel:SIMILAR_TO]->(r2)
  SET rel.score = similarity, rel.mesa = r2.mesa
  ",
  {batchSize: 10, parallel: false}
);

//Código para asignar ranking de similitud (1 al 10)
// Guardar ranking de similitud entre recomendaciones
CALL apoc.periodic.iterate(
  "
  MATCH (r:Recomendacion)-[rel:SIMILAR_TO]->(:Recomendacion)
  RETURN DISTINCT r
  ",
  "
  MATCH (r)-[rel:SIMILAR_TO]->(:Recomendacion)
  WITH r, rel
  ORDER BY rel.score DESC
  WITH r, collect(rel) AS rels
  UNWIND range(0, size(rels)-1) AS idx
  WITH rels[idx] AS rel, idx + 1 AS rank
  SET rel.rank = rank
  ",
  {batchSize: 10, parallel: false}
);



