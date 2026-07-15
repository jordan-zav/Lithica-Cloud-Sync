# ⚖️ Licencia / License (Dual Licensing)

Este proyecto se distribuye bajo un modelo de **Licencia Dual**:

1. **Uso de Código Abierto (GNU GPLv3):** Puedes usar, estudiar, modificar y redistribuir este software de forma gratuita, siempre y cuando cualquier versión modificada o distribución derivada también sea 100% de código abierto bajo la licencia GNU GPLv3.
2. **Uso Comercial / Privado (Licencia Comercial):** Si deseas integrar este código en software propietario, cerrado o comercial (sin la obligación de abrir tu propio código fuente bajo la GPLv3), debes adquirir una licencia comercial exclusiva. Por favor, ponte en contacto con el autor para acordar los términos.

Para más detalles, consulta el archivo [LICENSE](LICENSE).

---
# Lithica Cloud Sync para QGIS

Lithica Cloud Sync conecta QGIS con los proyectos sincronizados por Lithica Explorer y Lithica Mapper en Google Drive.

La versión 2.0.3 detecta proyectos de ambas aplicaciones, lee el nombre real desde los ZIP existentes y usa el cliente OAuth oficial de Lithica Cloud Sync.

## Compatibilidad

- Lithica Explorer con esquema lithica.drive.sync.v1 y observations.gpkg.
- Lithica Mapper con esquema lithica.drive.sync.v2 y map.gpkg.
- QGIS 3.34 o posterior.
- Windows, Linux y macOS con acceso a Google Drive mediante OAuth 2.0.

## Funciones principales

- Conexión segura con Google Drive usando el permiso limitado drive.file.
- Detección de las carpetas Lithica Explorer y Lithica Mapper en Mi unidad.
- Identificación visible del producto de origen en la lista de proyectos.
- Descarga y validación segura de los archivos ZIP.
- Apertura automática de todas las capas disponibles en el GeoPackage.
- Grupos separados para Explorer y Mapper dentro del árbol de capas de QGIS.
- Caché local reemplazable para actualizar proyectos descargados.

## Instalación

1. Descarga Lithica Cloud Sync-2.0.3.zip desde la sección Releases del repositorio.
2. Abre QGIS.
3. Ve a Complementos y luego a Administrar e instalar complementos.
4. Selecciona Instalar a partir de ZIP.
5. Elige el archivo descargado y confirma la instalación.
6. Abre el panel Lithica Cloud Sync.

## Uso

1. Pulsa Conectar y autoriza tu cuenta de Google Drive.
2. Pulsa Actualizar lista.
3. Selecciona un proyecto identificado como Explorer o Mapper.
4. Pulsa Descargar y abrir.
5. Las capas aparecerán bajo el grupo correspondiente en QGIS.

## Seguridad

El plugin no incluye credenciales privadas ni cuentas de servicio. La autorización se realiza mediante OAuth 2.0 y se almacena usando el sistema de autenticación de QGIS.

Los archivos descargados se validan antes de extraerse. Se rechazan rutas inseguras, enlaces simbólicos, esquemas desconocidos y archivos que excedan los límites configurados.

## Soporte

Desarrollado por [GisGeo Dev](https://gisgeo.dev).

Para consultas o errores, utiliza el [seguimiento de incidencias](https://github.com/jordan-zav/lithica-cloud-sync/issues).

## Licencia

Este proyecto está sujeto a los términos de la licencia GNU GPLv3 y el acuerdo de Licencia Dual descrito al inicio de este documento. Ver el archivo [LICENSE](LICENSE) para más detalles.
