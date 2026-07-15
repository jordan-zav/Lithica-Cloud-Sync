# Copyright (c) 2026 Jordan Zavaleta
# This file is part of lithica-cloud-sync.
# lithica-cloud-sync is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

import os
import sys
import tempfile
from pathlib import Path
from types import SimpleNamespace

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

PLUGIN_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PLUGIN_ROOT))

from qgis.core import (
    QgsApplication,
    QgsFeature,
    QgsGeometry,
    QgsPointXY,
    QgsProject,
    QgsVectorFileWriter,
    QgsVectorLayer,
)


class FakeIface:
    def __init__(self):
        self.active_layer = None

    def setActiveLayer(self, layer):
        self.active_layer = layer


def main():
    app = QgsApplication([], False)
    app.initQgis()
    try:
        from lithica_drive_sync import classFactory
        from lithica_drive_sync.layers import open_project_layers

        assert callable(classFactory)
        plugin = classFactory(FakeIface())
        assert plugin.__class__.__name__ == "LithicaDriveSyncPlugin"
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "observations.gpkg"
            source = QgsVectorLayer("Point?crs=EPSG:4326", "observations", "memory")
            feature = QgsFeature()
            feature.setGeometry(QgsGeometry.fromPointXY(QgsPointXY(-77.0, -12.0)))
            assert source.dataProvider().addFeature(feature)
            options = QgsVectorFileWriter.SaveVectorOptions()
            options.driverName = "GPKG"
            options.layerName = "observations"
            result = QgsVectorFileWriter.writeAsVectorFormatV3(
                source,
                str(path),
                QgsProject.instance().transformContext(),
                options,
            )
            assert result[0] == QgsVectorFileWriter.NoError, result
            extracted = SimpleNamespace(
                project_id="runtime-test",
                project_name="Runtime Test",
                geopackage=path,
            )
            iface = FakeIface()
            layers = open_project_layers(iface, extracted)
            assert len(layers) > 0
            layer = layers[0]
            assert layer.isValid()
            assert iface.active_layer is layer
            assert layer.customProperty("lithica/projectId") == "runtime-test"
            for l in layers:
                QgsProject.instance().removeMapLayer(l.id())
            iface.active_layer = None
            del layers
        print("PyQGIS runtime test: PASS")
    finally:
        QgsProject.instance().clear()
        app.exitQgis()


if __name__ == "__main__":
    main()
