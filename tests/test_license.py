from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def test_repository_uses_complete_gpl_v3_or_later_license():
    license_text = (ROOT / "LICENSE").read_text(encoding="utf-8")
    readme_text = (ROOT / "README.md").read_text(encoding="utf-8")

    assert license_text.lstrip().startswith("GNU GENERAL PUBLIC LICENSE")
    assert "Version 3, 29 June 2007" in license_text
    assert "END OF TERMS AND CONDITIONS" in license_text
    assert "GPL-3.0-or-later" in readme_text
    assert "Licencia Dual" not in readme_text
    assert "Licencia Comercial" not in readme_text


def test_plugin_python_sources_declare_gpl_v3_or_later():
    source_files = sorted((ROOT / "lithica_drive_sync").glob("*.py"))

    assert source_files
    for source_file in source_files:
        text = source_file.read_text(encoding="utf-8")
        assert "either version 3 of the License" in text, source_file.name
        assert "(at your option) any later version" in text, source_file.name
