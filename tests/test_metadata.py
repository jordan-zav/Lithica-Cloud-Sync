from pathlib import Path


def test_metadata_declares_official_qgis_plugin():
    path = (
        Path(__file__).resolve().parents[1]
        / "lithica_drive_sync"
        / "metadata.txt"
    )
    text = path.read_text(encoding="utf-8")

    assert "name=Lithica Cloud Sync" in text
    assert "Lithica Explorer and Mapper" in text
    assert "version=2.0.0" in text
    assert "experimental=False" in text
    assert "qgisMinimumVersion=3.34" in text
