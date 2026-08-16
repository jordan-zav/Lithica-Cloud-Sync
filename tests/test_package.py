import os
import subprocess
import zipfile
from pathlib import Path


def test_package_uses_portable_zip_paths(tmp_path):
    plugin_root = Path(__file__).resolve().parents[1]
    builds_root = tmp_path / "builds"
    releases_root = builds_root / "Releases"
    environment = os.environ.copy()
    environment["LITHICA_BUILDS_ROOT"] = str(builds_root)
    environment["LITHICA_RELEASES_ROOT"] = str(releases_root)
    subprocess.run(
        [
            "powershell",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(plugin_root / "package_plugin.ps1"),
        ],
        check=True,
        capture_output=True,
        text=True,
        env=environment,
    )
    target = (
        releases_root
        / "CloudSync"
        / "qgis"
        / "Lithica Cloud Sync-2.0.4.zip"
    )

    with zipfile.ZipFile(target) as package:
        names = package.namelist()
        license_text = package.read("lithica_drive_sync/LICENSE").decode("utf-8")

    assert "lithica_drive_sync/metadata.txt" in names
    assert "lithica_drive_sync/LICENSE" in names
    assert "lithica_drive_sync/catalog.py" in names
    assert not any("\\" in name for name in names)
    assert "GNU GENERAL PUBLIC LICENSE" in license_text
    assert "Version 3, 29 June 2007" in license_text
    assert "END OF TERMS AND CONDITIONS" in license_text
