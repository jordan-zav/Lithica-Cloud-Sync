# Recursos de compilación compartidos

La raíz por defecto para Lithica y PetroPy es D:\DevResources. DEV_RESOURCES_ROOT permite elegir otra carpeta. Se conservan los overrides LITHICA_BUILDS_ROOT y PETROPY_BUILD_ROOT; para compartir recursos deben apuntar a la misma raíz.

- Shared contiene SDK, dependencias y cachés reutilizables.
- Cada producto conserva su workspace y sus intermedios separados.
- Sessions contiene temporales únicos por ejecución.
- Locks protege las tareas simultáneas mediante archivos abiertos en exclusividad. Los bloqueos se liberan incluso cuando falla una tarea.
- Secrets, Config, KnowledgeBase, Runtime y Releases contienen recursos persistentes; no son carpetas de limpieza general.

Los lanzadores controlados admiten dos compilaciones pesadas simultáneas por defecto. DEV_MAX_PARALLEL_BUILDS cambia ese límite entre 1 y 16. DEV_BUILD_JOBS vale 2 por defecto para compiladores nativos; Gradle tiene dos trabajadores por proyecto. Dos tareas del mismo producto esperan su turno para proteger las copias de trabajo y la inyección de configuración. Los programas ya instalados se ejecutan de forma independiente.

El plugin Gradle de Flutter tiene una copia mutable por producto. Sus identificadores de plugin permanecen intactos. La instalación de los SDK compartidos se bloquea y vuelve a comprobar su existencia al obtener el turno.

Los scripts de compilación no detienen los daemons de Gradle compartidos. Una salida de GeoTech abierta en otra aplicación se informa como ocupada en lugar de cerrar el programa. GeoModeller reutiliza un backend GemPy activo. PetroPy prepara su entorno bajo bloqueo y luego permite ejecutar instancias con temporales distintos.

Usar los lanzadores del repositorio activa estas protecciones. Ejecutar flutter, gradle o python directamente no activa la cola. Las ejecuciones de desarrollo de Flutter del mismo producto pueden esperar hasta que termine la sesión anterior.

Las carpetas antiguas de D: se conservan como enlaces de compatibilidad para entornos y herramientas que contienen rutas absolutas. No son copias adicionales de los recursos. No borrarlas sin revisar esas referencias.

Tras limpiar cachés, la siguiente compilación descargará o regenerará sus intermedios y puede tardar más. No se limpian automáticamente sesiones ajenas por su antigüedad.
