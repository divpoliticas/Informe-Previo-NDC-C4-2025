# Sistematización Automatizada de Comentarios NDC 2025 🇨🇱

> **Resumen**  
> Este proyecto implementa un flujo reproducible en Python que descarga comentarios cualitativos
> desde una hoja de cálculo colaborativa, los contextualiza, y emplea la API de OpenAI para  
> **clasificar** y **reescribir** cada aporte según criterios metodológicos explícitos.  
> El resultado final es un CSV listo para análisis posteriores (p. ej. minería de texto, redes
> semánticas o generación de recomendaciones de política pública).

---

## 1. Motivación académica

La actualización de la Contribución Determinada a Nivel Nacional (NDC 2025) de Chile
ha convocado diálogos participativos multi‑actor.  
Para garantizar **trazabilidad analítica** y **coherencia discursiva** en los insumos
producidos, necesitamos transformar comentarios heterogéneos en registros normalizados:

1. **Clasificación tipológica**  
   - 🟩 Aporte conceptual o estratégico  
   - 🟦 Comentario operativo o técnico  
   - 🟧 Pregunta o punto crítico  
   - ⬜ Fragmento insuficiente

2. **Reescritura contextualizada**  
   Cada comentario se convierte en una frase completa que preserva intención,
   motivación y procedencia (mesa temática, área metodológica, instancia).

Este repositorio automatiza ambas tareas con ayuda de modelos de lenguaje avanzados,
manteniendo control metodológico sobre _prompting_, _rate limiting_ y auditoría de
resultados.

---

## 2. Estructura del repositorio

```
.
├── src/
│   └── procesar_comentarios.py   # script principal
├── prompts/
│   └── bosques_turberas.md       # ejemplo de contexto específico
├── data/
│   └── comentarios_procesados_<timestamp>.csv  # salidas generadas
├── requirements.txt
└── README.md
```

---

## 3. Requisitos

| Componente | Versión recomendada | Notas |
|------------|--------------------|-------|
| Python     | ≥ 3.10             | Uso intensivo de *f‑strings* y `match` opcional |
| pandas     | 2.x                | Manejo de CSV remotos y _DataFrame_ vectorizado |
| openai     | 1.x                | Cliente oficial; soporta `chat.completions` |
| python-dotenv* | 1.x            | (Opcional) para gestionar la clave API por entorno |

Instala todo con:

```bash
pip install -r requirements.txt
```

---

## 4. Variables de entorno

| Variable           | Descripción                                                |
|--------------------|------------------------------------------------------------|
| `OPENAI_API_KEY`   | Clave secreta generada en la consola de OpenAI             |
| `CSV_URL`          | Enlace **public‑CSV** de Google Sheets (ver Sección 6)     |
| `OPENAI_MODEL`     | `gpt-4o` (por defecto) o `gpt-3.5-turbo` si prima la velocidad |

> **Seguridad**: nunca almacenes la clave en el código; usa un archivo `.env`
> excluido por `.gitignore`.

---

## 5. Ejecución rápida

```bash
python src/procesar_comentarios.py
```

El script:

1. Descarga la hoja de cálculo.
2. Genera una narrativa por fila (mesa, área, instancia).
3. Llama a la API con el _prompt_ temático correspondiente.
4. Extrae la respuesta con expresiones regulares robustas.
5. Almacena resultados y registra un timestamp en el nombre del archivo.

---

## 6. Adaptación a nuevas temáticas

1. Coloca el bloque de **contexto** (definiciones, compromisos, indicadores) en
   `prompts/<tema>.md`.
2. Declara `prompt_sistema = open('prompts/<tema>.md').read()` dentro del script.
3. Ajusta `CSV_URL` para apuntar a la pestaña específica de Google Sheets que
   contenga los comentarios de esa temática.  
   - Asegúrate de publicar la hoja como CSV (`Archivo ▸ Compartir ▸ Publicar en la web`).

---

## 7. Buenas prácticas de investigación computacional

| Práctica | Justificación metodológica |
|----------|----------------------------|
| **Trazabilidad**: se conserva el `ID` original y se añade el _timestamp_ al archivo de salida. | Facilita auditoría y replicabilidad. |
| **Rate limiting** (`time.sleep(3)`) | Previene _throttling_ de la API y respeta fair use. |
| **Extracción con `re`** | Permite validar la estructura de la respuesta y detectar anomalías. |
| **Log de errores y re‑intentos** | Evita la pérdida silenciosa de filas; esencial en investigación cualitativa. |

---

## 8. Resultados esperados

| Columna de salida            | Descripción                                              |
|------------------------------|----------------------------------------------------------|
| `ID`                         | Identificador único de la fila original                 |
| `Tipo clasificado`           | Una de las cuatro categorías predefinidas               |
| `Comentario reescrito`       | Frase única, coherente y contextualizada                |
| `Mesa`, `Area`, `Dialogo…`   | Metadatos heredados del CSV original                    |

Los analistas pueden importar el CSV a R, Python o Neo4j para continuar con
*topic modelling*, análisis de redes o dashboards de seguimiento.

---

## 9. Ética y limitaciones

1. **Dependencia del modelo**: la clasificación es tan fiable como el _prompt_
   y el modelo subyacente. Se recomienda muestreo manual para control de calidad.
2. **Sesgo de contexto**: cada bloque temático debe revisarse por expertos
   disciplinares para evitar interpretaciones sesgadas.
3. **Privacidad**: si los comentarios incluyen datos personales, anonimiza antes
   de procesar.

---

## 10. Créditos y citación

Este flujo fue diseñado por el equipo de investigación de la **Mesa de
Sistematización Científica** en el marco del proyecto  
«**Participación Experta para la NDC 2025**».  
Si usas este código o sus derivados, cita de la siguiente manera:

> Morales, C. et al. (2025). *Pipeline de clasificación y reescritura de comentarios NDC 2025* [Software]. GitHub. <https://github.com/usuario/repositorio>

---

## 11. Licencia

Distribuido bajo **MIT License** para el código y **CC‑BY‑SA 4.0** para los
prompts y la documentación. Consulta `LICENSE.md` para más detalles.
