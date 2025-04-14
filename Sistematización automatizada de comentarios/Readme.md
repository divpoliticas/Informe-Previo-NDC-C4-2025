# Sistematización Automatizada de Comentarios talleres de participación

> **Resumen**  
> Este proyecto implementa un flujo reproducible en Python que descarga comentarios cualitativos desde una hoja de cálculo colaborativa, los contextualiza, y emplea la API de OpenAI para **clasificar** y **reescribir** cada aporte según criterios metodológicos explícitos.  
> El resultado final es un CSV listo para análisis posteriores (p. ej. minería de texto, redes semánticas o generación de recomendaciones de política pública).

---

## 1. Contexto y propósito

En el contexto de la actualización de la Contribución Determinada a Nivel Nacional (NDC 2025) de Chile el Comité Científico de Cambio Climático desarrolló instancias participativas a través de una convocatoria llamada "Diálogos científicos por la acción climática".  
Para garantizar **trazabilidad analítica** y **coherencia discursiva** en los insumos producidos, se requería transformar comentarios heterogéneos en registros normalizados:

1. **Clasificación tipológica**  
   - 🟩 Aporte conceptual o estratégico  
   - 🟦 Comentario operativo o técnico  
   - 🟧 Pregunta o punto crítico  
   - ⬜ Fragmento insuficiente

2. **Reescritura contextualizada**  
   Cada comentario se convierte en una frase completa que preserva intención, motivación y procedencia (mesa temática, área metodológica, instancia).

Este repositorio automatiza ambas tareas con ayuda de modelos de lenguaje avanzados, manteniendo control metodológico sobre _prompting_, _rate limiting_ y auditoría de resultados.

---

## 2. Estructura del repositorio

```
mi_proyecto/
├── insumos.md                  # ← único archivo con mesas + URLs + contextos
├── src/
│   └── procesar_comentarios.py
├── data/
│   └── comentarios_procesados_<timestamp>.csv
├── requirements.txt
└── README.md                   # este archivo
```
### 2.1 Formato de `insumos.md`

Cada tema (mesa) se anota de la siguiente forma, uno debajo de otro:

```markdown
## Mesa: Bosques y Turberas
CSV: https://docs.google.com/spreadsheets/d/…/export?format=csv

<pegas aquí el BLOQUE DE CONTEXTO completo para esa mesa>

---

## Mesa: Transición Energética
CSV: https://docs.google.com/spreadsheets/d/…/export?format=csv

<otro bloque de contexto>

---
```

- **`## Mesa:`** sirve como separador visible.  
- **`CSV:`** debe ser el enlace público‑CSV de la pestaña correspondiente.  
- Tras la línea `CSV:` pega **todo** el contexto que usarás en el prompt.

## 2.2 Cómo usar `insumos.md` en la práctica

1. **Abre** `insumos.md` y localiza la mesa que quieras procesar.  
2. **Copia**:
   - La URL después de `CSV:` → pégala en la variable `csv_url` de `procesar_comentarios.py`.
   - Todo el bloque de contexto → pégalo en `prompt_sistema` (sustituyendo el anterior).  
3. **Ejecuta** el script:

   ```bash
   python src/procesar_comentarios.py
   ```

4. **Repite** los pasos 1‑3 cada vez que cambies de mesa.

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
| `OPENAI_MODEL`     | `gpt-4o-mini` (por defecto) o `gpt-3.5-turbo` |

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

1. Coloca el bloque de **contexto** (definiciones, compromisos, indicadores) proveniente de `insumos.md`.
2. Ajusta `CSV_URL` para apuntar a la pestaña específica de Google Sheets que contenga los comentarios de esa temática.  
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

Los analistas pueden importar el CSV a R, Python o Neo4j para continuar con *topic modelling*, análisis de redes o dashboards de seguimiento.

---

## 9. Ética y limitaciones

1. **Dependencia del modelo**: la clasificación es tan fiable como el _prompt_ y el modelo subyacente. Se recomienda muestreo manual para control de calidad.
2. **Sesgo de contexto**: cada bloque temático debe revisarse por expertos disciplinares para evitar interpretaciones sesgadas.
3. **Privacidad**: si los comentarios incluyen datos personales, anonimiza antes de procesar.

---

## 10. Créditos y citación

Este flujo fue diseñado por el equipo de la Secretaría Técnica del Comité Científico Asesor en el marco de los **Diálogos Científicos por la acción Climática 2025**».  
Si usas este código o sus derivados, cita de la siguiente manera:

> Morales, C. et al. (2025). *Pipeline de clasificación y reescritura de comentarios NDC 2025* [Software]. GitHub. <https://github.com/usuario/repositorio>

---

## 11. Licencia

Distribuido bajo **MIT License** para el código y **CC‑BY‑SA 4.0** para los
prompts y la documentación. Consulta `LICENSE.md` para más detalles.
