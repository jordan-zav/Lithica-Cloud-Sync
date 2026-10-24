# Instrucciones de trabajo

Se aplican las instrucciones de recursos y conservación del AGENTS.md superior. Mantén código en E: y utiliza SDK, cachés y temporales de herramientas en D:\DevResources mediante los lanzadores existentes.

Conserva la selección explícita de cuenta en OAuth de escritorio para que otra sesión de Google del navegador no impida cambiar de cuenta. Este complemento de QGIS no tiene una sesión Firebase de Lithica; no inventes una identidad de Lithica para compararla. Si se integra esa sesión, Drive deberá usar la misma cuenta y un rechazo deberá descartar solo la autorización local de Drive, sin revocar permisos remotos ni cerrar Firebase, permitiendo elegir de nuevo. Añade pruebas de ese reintento al introducir la integración.

No uses backticks ni acentos similares como delimitadores en reportes Markdown o Word.
