# Selección de cuenta de Drive

El OAuth de escritorio ahora solicita select_account junto con consent. Así el navegador permite elegir otra cuenta en cada conexión explícita, aunque tenga una sesión de Google guardada. Se conserva el alcance de Drive existente.

Las 24 pruebas unitarias de tests pasaron, incluida la comprobación del selector en la URL de autorización. Las pruebas de tests_qgis requieren el entorno QGIS y no se ejecutaron dentro de ese entorno en esta revisión; la prueba inicial con Python general confirmó que ese intérprete no tiene el módulo qgis.

Este complemento no tiene una sesión Firebase de Lithica. La comparación con esa identidad no aplica actualmente. La regla queda documentada para una futura integración: usar la misma cuenta, descartar únicamente la autorización local equivocada y permitir elegir de nuevo sin revocar permisos remotos ni cerrar Firebase.
