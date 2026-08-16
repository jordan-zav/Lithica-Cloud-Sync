# Lithica Cloud Sync para QGIS

Lithica Cloud Sync conecta QGIS con los proyectos sincronizados por Lithica Explorer y Lithica Mapper en Google Drive.

La versión 2.0.4 detecta proyectos de ambas aplicaciones, crea un inventario eficiente con los metadatos de Google Drive y permite buscar localmente sin hacer solicitudes por cada proyecto o pulsación.


## ⚖️ Licencia

A partir de la versión 2.0.4, este proyecto se distribuye exclusivamente bajo la **GNU General Public License versión 3 o posterior** (`GPL-3.0-or-later`). Puedes usarlo, estudiarlo, modificarlo y distribuirlo, incluso con fines comerciales, respetando los términos de la GPL.

Consulta el texto completo en [LICENSE](LICENSE). Las versiones anteriores conservan la licencia bajo la cual fueron publicadas.

---

## Compatibilidad

- Lithica Explorer con esquema lithica.drive.sync.v1 y observations.gpkg.
- Lithica Mapper con esquema lithica.drive.sync.v2 y map.gpkg.
- QGIS 3.34 o posterior.
- Windows, Linux y macOS con acceso a Google Drive mediante OAuth 2.0.

## Funciones principales

- Conexión segura con Google Drive usando el permiso limitado drive.file.
- Detección de las carpetas Lithica Explorer y Lithica Mapper en Mi unidad.
- Identificación visible del producto de origen en la lista de proyectos.
- Inventario agrupado de Drive y búsqueda local rápida, tolerante a mayúsculas y tildes.
- Descarga y validación segura de los archivos ZIP.
- Apertura automática de todas las capas disponibles en el GeoPackage.
- Grupos separados para Explorer y Mapper dentro del árbol de capas de QGIS.
- Caché local reemplazable para actualizar proyectos descargados.

## Instalación

1. Descarga Lithica Cloud Sync-2.0.4.zip desde la sección Releases del repositorio.
2. Abre QGIS.
3. Ve a Complementos y luego a Administrar e instalar complementos.
4. Selecciona Instalar a partir de ZIP.
5. Elige el archivo descargado y confirma la instalación.
6. Abre el panel Lithica Cloud Sync.

## Uso

1. Pulsa Conectar y autoriza tu cuenta de Google Drive.
2. Pulsa Actualizar lista.
3. Escribe en el buscador para filtrar localmente el inventario, si lo necesitas.
4. Selecciona un proyecto identificado como Explorer o Mapper.
5. Pulsa Descargar y abrir.
6. Las capas aparecerán bajo el grupo correspondiente en QGIS.

## Seguridad

El plugin no incluye credenciales privadas ni cuentas de servicio. La autorización se realiza mediante OAuth 2.0 y se almacena usando el sistema de autenticación de QGIS.

Los archivos descargados se validan antes de extraerse. Se rechazan rutas inseguras, enlaces simbólicos, esquemas desconocidos y archivos que excedan los límites configurados.

## Soporte

Desarrollado por [GisGeo Dev](https://gisgeo.dev).

Para consultas o errores, utiliza el [seguimiento de incidencias](https://github.com/jordan-zav/lithica-cloud-sync/issues).
