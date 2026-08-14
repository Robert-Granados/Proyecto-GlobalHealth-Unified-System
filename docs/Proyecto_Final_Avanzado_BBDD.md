# **PROYECTO FINAL INTEGRADOR** 

### **Estrategia de Arquitectura Híbrida y Distribución de Datos Multi-Modelo** 



## **1. Introducción y Propósito del Proyecto** 

El objetivo de este proyecto final es diseñar, configurar y defender una infraestructura de datos integral y multimodelo. Las parejas de estudiantes deberán resolver un desafío empresarial de alta complejidad donde se requiere almacenar e integrar simultáneamente estructuras basadas en el paradigma **Objeto-Relacional** , datos altamente dinámicos y autovalidados en **XML** , documentos libres de esquema en **NoSQL (MongoDB)** , configurando a la vez estrategias de distribución física mediante **Replicación Maestro/Esclavo** , **Fragmentación Horizontal/Vertical** y despliegue final en entornos de la **Nube** . 

**Desafío Académico (25% de la Nota Final):** Este proyecto integra el 100% de la carta temática del curso en una única arquitectura conectada. Cada componente de software y comando ejecutado debe responder a un diseño de ingeniería formal que los estudiantes justificarán en una defensa oral presencial el día **17/08/2026 (Semana 14)** . 

## **2. Caso de Negocio: "GlobalHealth Unified System"** 

La corporación médica _GlobalHealth_ cuenta con clínicas en tres países de Centroamérica y requiere migrar su infraestructura centralizada debido a problemas de latencia, seguridad de datos y heterogeneidad de sus registros médicos. El sistema debe gestionar tres grandes dominios de información, mapeados rigurosamente a las tecnologías del curso: 

1. **Capa Física y de Empleados (Objeto-Relacional):** Gestión del personal médico interno, clínicas y equipos utilizando estructuras jerárquicas y tipos compuestos (MOR). 

2. **Capa de Expediente Clínico Regulado (XML):** Almacenamiento de historiales de diagnóstico clínico que deben cumplir estrictamente con esquemas de validación regulatoria internacional (XSD/Plantillas). 

3. **Capa de Telemetría e Interacciones (NoSQL/MongoDB):** Ingesta masiva y veloz de logs de sensores de monitoreo continuo del paciente y consultas de telemedicina. 

## **3. Requerimientos Técnicos por Unidades Curriculares** 

### **Unidad I. Otros Modelos de Datos (Mapeo de Almacenamiento)** 

Los estudiantes deberán implementar las tres bases de datos correspondientes a cada modelo: 

Pág. 1 de 3 

Proyecto Final Integrador - Bases de Datos Avanzadas - 17/08/2026 

|**Modelo**|**Requerimiento Técnico Obligatorio**|**Tecnología Sugerida**|
|---|---|---|
|**1. Objeto-Relacional**<br>**(MOR)**|Creación de**tipos compuestos (clases)**, atributos<br>complejos, funciones internas del tipo, relaciones de<br>composición/agregación y herencia de tipos. Uso de<br>**tablas tipadas**y**tablas anidadas / colecciones**<br>**vectorizadas**para teléfonos o especialidades<br>médicas. Operaciones completas CRUD sobre estas<br>tablas tipadas.|**`PostgreSQL / Oracle SQL`**|
|**2. Tipo de datos XML**|Creación de columnas tipo`XML`. Declaración,<br>registro, actualización y borrado de una**plantilla de**<br>**validación (XML Schema - XSD)**. Forzar la<br>validación estricta de los documentos XML<br>insertados. Demostrar el CRUD sobre porciones<br>internas del XML (extracción de nodos y<br>subconjuntos mediante funciones de análisis<br>nativas).|**`PostgreSQL / SQL Server`**|
|**3. NoSQL (MongoDB)**|Modelado de colecciones de telemetría médica en<br>formato**JSON/BSON**con identificadores únicos.<br>Aplicación práctica del modelo de dependencia<br>documental (**Abuelo-Padre-Hijo**: Paciente -> Sesión<br>-> Logs de Sensores). Inserciones, actualizaciones y<br>consultas complejas aplicando**operadores de**<br>**relación**, límites y**operaciones de agregación /**<br>**JOINs NoSQL**(`$lookup`) con otras colecciones.|**`MongoDB Atlas`**|



### **Unidad II. Distribución y Nube (Mapeo de Infraestructura)** 

Para asegurar la escalabilidad horizontal, alta disponibilidad y consistencia del sistema global, se deben implementar las siguientes tácticas distribuidas: 

- **1. Replicación Maestro/Esclavo:** Configurar la base de datos transaccional en un esquema distribuido de dos contenedores Docker. El **Servidor Maestro** procesa escrituras del personal médico; el **Servidor Esclavo (Réplica)** recibe las consultas de lectura pesadas del dashboard administrativo. Los estudiantes deben configurar permisos, inicializar, validar la réplica y demostrar la parada controlada del servicio en la defensa. 

- **2. Fragmentación de Datos (Clustering):** Simular la distribución por zonas geográficas de la tabla global de pacientes mediante: 

   - **Fragmentación Horizontal:** Dividir los registros de pacientes por región geográfica (Clínica Norte vs Clínica Sur) alojándolos en nodos separados. 

   - **Fragmentación Vertical:** Separar los datos confidenciales financieros de las clínicas de los datos públicos y operativos de contacto del paciente (cumpliendo con la regla de llaves primarias idénticas para la reconstrucción de la relación). 

- **3. Implementación en la Nube (Cloud Computing):** Evaluar de forma cuantitativa el costo/beneficio de migrar la telemetría de MongoDB hacia un servicio en la nube pública (ej: MongoDB Atlas / AWS). Configurar y desplegar la colección de MongoDB en un cluster real en la nube, exponiendo la cadena de conexión segura mediante una interfaz de consumo funcional. 

Pág. 2 de 3 

Proyecto Final Integrador - Bases de Datos Avanzadas - 17/08/2026 



<!-- Start of picture text -->
⚠️<br><!-- End of picture text -->

#### **`⚠️` CLÁUSULA ANTI-PLAGIO DE IA:** 

El código o configuración que intente evadir las restricciones de validación XML (por ejemplo, insertar XML plano mal formado sin vincular el XSD registrado en base de datos) o que no implemente de forma nativa la separación física de conexiones del backend al Master y al Esclavo, será sancionado con la pérdida total del apartado correspondiente. 

## **4. Dinámica y Rúbrica de Exposición (Semana 14 - 15 Minutos)** 

El proyecto se defenderá presencialmente el **17/08/2026** . No se aceptarán explicaciones meramente visuales de la aplicación. La evaluación se centrará en la arquitectura e infraestructura de bases de datos. 

|**Rubro**|**Porcentaje**|**Criterio Técnico Evaluado**|
|---|---|---|
|**Arquitectura Híbrida**<br>**(MOR + XML + NoSQL)**|**8.5%**|Implementación perfecta de tablas tipadas, herencia y agregación en<br>MOR. Uso correcto de plantillas XML (XSD) y operaciones atómicas de<br>extracción de datos. Diseño jerárquico óptimo en MongoDB.|
|**Infraestructura**<br>**Distribución (Docker**<br>**Replicación)**|**7.5%**|Maestro/Esclavo corriendo en contenedores aislados. Demostración<br>funcional en vivo donde el Master es apagado en la consola y el Esclavo<br>continúa sirviendo las consultas de lectura.|
|**Fragmentación y Nube**|**5.0%**|Diagramación de la fragmentación horizontal/vertical. Cluster de base<br>de datos aprovisionado en la nube y consumo a través de API segura.<br>Evaluación de costo/beneficio adjunta en el PDF.|
|**Defensa Oral e**<br>**Integración**|**4.0%**|Dominio conceptual del Teorema CAP, modelo BASE, consistencia de<br>datos y respuestas oportunas de la pareja a las preguntas del profesor<br>durante los 15 minutos de defensa (simulacro de Chaos Engineering en<br>vivo).|
|**TOTAL**|**25.0%**|**Proyecto Final de Graduación del Curso. Entrega oficial:**<br>**17/08/2026.**|



Pág. 3 de 3 

Proyecto Final Integrador - Bases de Datos Avanzadas - 17/08/2026 

