# Instrucciones de trabajo

Se aplican las instrucciones de recursos y conservación del AGENTS.md superior. Conserva los clones existentes en la raíz real de cada equipo: E: en la laptop y O:\0. Projects\LithicaRepos en esta PC. Utiliza SDK, cachés y temporales de herramientas en D:\DevResources mediante los lanzadores existentes.

Conserva la selección explícita de cuenta en OAuth de escritorio para que otra sesión de Google del navegador no impida cambiar de cuenta. Este complemento de QGIS no tiene una sesión Firebase de Lithica; no inventes una identidad de Lithica para compararla. Si se integra esa sesión, Drive deberá usar la misma cuenta y un rechazo deberá descartar solo la autorización local de Drive, sin revocar permisos remotos ni cerrar Firebase, permitiendo elegir de nuevo. Añade pruebas de ese reintento al introducir la integración.

No uses backticks ni acentos similares como delimitadores en reportes Markdown o Word.

## Recursos de desarrollo y conservacion

Antes de tareas que requieran muchos tokens, avisa y usa consultas directas y acotadas.
Usa D:\DevResources como raiz local cuando exista y sea adecuada; verifica unidades fisicas, espacio y destinos en cada PC. Si no es valida, pide elegir una raiz antes de migrar.
Reutiliza SDK y dependencias existentes. Comparte caches compatibles mediante Shared, separa estado mutable por proyecto y copia de trabajo, y crea temporales unicos por ejecucion en Sessions.
Configura TEMP y TMP solamente en la sesion y sus procesos hijos. Conserva ajustes particulares de esta PC en configuracion local, sin trasladarlos innecesariamente a configuraciones compartidas.
Usa los lanzadores y bloqueos existentes. Maximo dos compilaciones pesadas simultaneas y exclusion para escrituras sobre el mismo workspace. No cierres programas ni detengas procesos ajenos.
En esta PC los lanzadores BAT integrados usan .devresources.local.cmd, configuracion local ignorada por Git. Para comandos directos usa DEVRESOURCES_RUN.cmd; verifica DEVRESOURCES_SESSION antes de ejecutar herramientas fuera de los lanzadores.
Antes de modificar recursos revisa instrucciones, remotos, ramas y cambios locales. Actualiza solo mediante pull con avance rapido; no uses reset, cambios de rama, descartes ni limpieza destructiva. Informa divergencias y continua con otros repositorios.
Corrige y comprueba rutas y lanzadores antes de consolidar duplicados. Conserva codigo, datos, autenticacion, claves, recursos necesarios y enlaces de compatibilidad. No dupliques recursos en C: ni en otros discos. No modifiques DriveFS, datos ni sincronizacion de Google Drive.
Antes de CUALQUIER eliminacion informa al usuario y espera su autorizacion. Solo considera caches o temporales regenerables e inactivos, despues de verificar referencias, copias y destinos fisicos. No ejecutes limpieza automatica durante esta auditoria.
No generes APK/AAB salvo solicitud expresa. No afirmes haber verificado compilaciones que no ejecutaste. Los informes Markdown o Word no deben usar backticks.
