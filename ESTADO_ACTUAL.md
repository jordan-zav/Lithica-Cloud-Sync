# Lithica Cloud-Sync: estado actual

Revisión documental: 26 de octubre de 2026.

Plugin QGIS de lectura de proyectos respaldados por Explorer y Mapper. El código declara la versión 2.0.4 y QGIS mínimo 3.34.

## Flujo y límites

Explorer utiliza el esquema lithica.drive.sync.v1 con observations.gpkg; Mapper utiliza lithica.drive.sync.v2 con map.gpkg. Conectar Drive, actualizar el inventario, seleccionar el proyecto y descargarlo permite abrir sus capas en QGIS. La edición en QGIS no se envía automáticamente de vuelta a la app.

El plugin solicita elegir una cuenta Google mediante OAuth de escritorio. No tiene una sesión Firebase de Lithica que permita exigir correspondencia de identidad; ese control pertenece a las apps que sí tienen ambas sesiones. Consulta [Identidad de Drive](docs/DRIVE_IDENTIDAD_2026-10-23.md).

Los ZIP se validan antes de extraerlos: rutas, enlaces, esquema y límites. La revisión documental no constituye una nueva prueba con QGIS abierto, una cuenta real o proyectos de producción. El paquete instalable se prepara con EMPAQUETAR_LITHICA_CLOUD_SYNC.bat; una versión en metadata.txt no acredita que haya un release adjunto en GitHub. Se conserva GPL-3.0-or-later y el texto de LICENSE.

## Desarrollo y recursos locales

En esta PC el código fuente está en E:\0. Projects\LithicaRepos. Las copias aisladas de código y los scripts auxiliares también deben permanecer en E:. Conserva los clones y la configuración propia de otros equipos; sincroniza cambios con Git y avance rápido, sin reemplazar cambios locales.

SDK, dependencias y cachés se reutilizan desde D:\DevResources\Shared. DART_DATA_HOME apunta a D:\DevResources\Shared\dart-data. Los temporales de herramientas se separan por producto y ejecución en D:\DevResources\Sessions, con TEMP y TMP configurados solo para esa sesión. Firmas y autorizaciones permanecen fuera de Git, en D:\DevResources\Secrets. Los paquetes finales se guardan en Releases.

Usa los lanzadores y bloqueos existentes: exclusión entre tareas que escriben el mismo workspace y un máximo de dos compilaciones pesadas simultáneas. No cierres otras aplicaciones para liberar archivos. Consulta [.build-support/README.md](.build-support/README.md) cuando este proyecto disponga del supervisor. Un push de documentación o código no publica binarios, reglas Firebase ni páginas web.

## Documentación y alcance de la revisión

[Índice completo](DOCUMENTACION.md) · [README](README.md). Los registros fechados mantienen sus resultados originales. Esta revisión comprueba documentación y referencias locales; no certifica pruebas físicas, despliegues ni consultas externas distintos de los expresamente fechados.
