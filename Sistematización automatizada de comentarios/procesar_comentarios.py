import pandas as pd
import time
import re
from openai import OpenAI

# Configuración
csv_url = "URL_CSV"
modelo = "gpt-4o"  # o gpt-3.5-turbo

# Crear cliente
client = OpenAI(api_key="XXX")

# Prompt que ya usas, completo con contexto y ejemplos
prompt_sistema = """Actúa como un investigador en ciencias sociales especializado en sistematización de talleres participativos. Tu tarea es analizar y reescribir comentarios emitidos por participantes en el proceso de actualización de la NDC 2025 de Chile. El objetivo es clasificar y estandarizar los comentarios de forma clara, coherente y contextualizada, como paso previo a transformarlos en recomendaciones de política pública.

⚠️ Siempre debes usar el contexto específico que te estoy entregando en este promt. 

---
CONTEXTO 
---

✍️ Ejemplos de comentarios reescritos:
En la mesa sobre Transición Socioecológica Justa, en la sección de interconexiones, se planteó la necesidad de priorizar la construcción de capacidades y la recapacitación laboral como elementos clave para una transición justa, destacando su rol estratégico en la reconversión productiva asociada al cambio climático.
En la Mesa 2 sobre Transición Energética, se plantea la necesidad de detallar cómo las contribuciones se implementarán a nivel regional y comunal, identificando los instrumentos habilitantes correspondientes y destacando los impactos esperados en los territorios subnacionales, con el fin de fortalecer la coherencia y eficacia en la gobernanza climática multinivel.
En la Mesa 2 sobre Transición Energética, en la sección de contribuciones del anteproyecto NDC, se solicitó justificar la meta del 20% en la medida M4, preguntando si esta fue definida en base a la experiencia previa de cumplimiento del NDC anterior y qué fundamentos técnicos respaldan su establecimiento.

---

1. Clasifica cada comentario según una de las siguientes categorías:
🟩 Aporte conceptual o estratégico
🟦 Comentario operativo o técnico
🟧 Pregunta o punto crítico
⬜ Fragmento insuficiente

2. Reescribe el comentario como una **frase única y completa**, que integre contexto, tema, intención, motivación. Siempre inicia con el contexto, como los ejemplos de comentarios que te entrego en este promt.

3. Si el comentario es un fragmento insuficiente, responde exactamente:
'Fragmento insuficiente. No es posible reescribir o interpretar el comentario de forma coherente, incluso contando con el contexto entregado.'

---

4. Formato final de respuesta (usa esto para cada comentario):
---
**Tipo de comentario:** [una de las 4 categorías]  
**Comentario reescrito:** [frase completa reescrita, si aplica]  
---

"""

# Cargar CSV y limpiar columnas
df = pd.read_csv(csv_url)
df.columns = df.columns.str.strip()
print("Columnas disponibles:", df.columns.tolist())

# Crear columna de narrativa
def crear_narrativa(row):
    texto = f"### Comentario:\n{row['Text']}\n"
    if pd.notnull(row['Mesa']):
        texto += f"**Mesa temática:** {row['Mesa']}\n"
    if pd.notnull(row['Area']):
        texto += f"**Área metodológica:** {row['Area']}\n"
    if pd.notnull(row['Dialogo Virtual o Presencial']):
        texto += f"**Instancia de origen:** {row['Dialogo Virtual o Presencial']}\n"
    return texto

df["narrativa"] = df.apply(crear_narrativa, axis=1)

# Procesar uno por uno
resultados = []

for index, row in df.iterrows():
    print(f"Procesando fila {index + 1}/{len(df)} - ID: {row['ID']}")
    try:
        response = client.chat.completions.create(
            model=modelo,
            messages=[
                {"role": "system", "content": prompt_sistema},
                {"role": "user", "content": row["narrativa"]}
            ]
        )
        content = response.choices[0].message.content

        tipo = re.search(r"\*\*Tipo de comentario:\*\*\s*(.*?)\n", content, re.DOTALL)
        texto_reescrito = re.search(r"\*\*Comentario reescrito:\*\*\s*(.*?)\n?---", content, re.DOTALL)

        df.at[index, "Tipo clasificado"] = tipo.group(1).strip() if tipo else None
        df.at[index, "Comentario reescrito"] = texto_reescrito.group(1).strip() if texto_reescrito else None

        resultados.append(index)
        time.sleep(3)  # Espera entre llamadas

    except Exception as e:
        print(f"Error en fila {index}: {e}")
        time.sleep(15)

# Guardar resultados
from datetime import datetime

timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
filename = f"comentarios_procesados_{timestamp}.csv"
df.to_csv(filename, index=False)
print(f"✅ Procesamiento completo. Archivo guardado como {filename}")
