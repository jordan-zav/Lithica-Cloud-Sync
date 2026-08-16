from datetime import datetime, timezone

from lithica_drive_sync.catalog import ProjectCatalog, display_name
from lithica_drive_sync.models import ProjectFile


def project(
    file_id,
    file_name,
    project_name=None,
    source_product="explorer",
):
    return ProjectFile(
        id=file_id,
        name=file_name,
        modified_time=datetime(2026, 8, 16, tzinfo=timezone.utc),
        size=10,
        source_product=source_product,
        project_name=project_name,
    )


def test_catalog_searches_the_loaded_inventory_locally():
    projects = [
        project("p1", "lithica-project-p1.zip", "Depósito Águila"),
        project(
            "m1",
            "lithica-project-regional.zip",
            "Mapa Regional",
            "mapper",
        ),
    ]
    catalog = ProjectCatalog()
    catalog.replace(projects)

    assert catalog.search("") == projects
    assert catalog.search("deposito aguila") == [projects[0]]
    assert catalog.search("regional mapper") == [projects[1]]
    assert catalog.search("p1") == [projects[0]]
    assert catalog.search("inexistente") == []


def test_display_name_uses_filename_without_remote_manifest_request():
    legacy = project("legacy", "lithica-project-legacy-2024.zip")

    assert display_name(legacy) == "legacy-2024"
