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

import json
import shutil
import zipfile
from pathlib import Path, PurePosixPath

from .models import ExtractedProject

SUPPORTED_SCHEMAS = {
    "explorer": "lithica.drive.sync.v1",
    "mapper": "lithica.drive.sync.v2",
}


class ArchiveError(ValueError):
    pass


def validate_and_extract(
    source: Path,
    destination: Path,
    max_compressed: int = 2 * 1024**3,
    max_extracted: int = 5 * 1024**3,
    max_entries: int = 20_000,
) -> ExtractedProject:
    source, destination = Path(source), Path(destination)
    if source.stat().st_size > max_compressed:
        raise ArchiveError("Archive exceeds compressed size limit")
    try:
        archive = zipfile.ZipFile(source)
    except (OSError, zipfile.BadZipFile) as error:
        raise ArchiveError(f"Invalid ZIP archive: {error}") from error
    with archive:
        entries = archive.infolist()
        if len(entries) > max_entries:
            raise ArchiveError("Archive has too many entries")
        names = set()
        total = 0
        for entry in entries:
            normalized = entry.filename.replace("\\", "/")
            path = PurePosixPath(normalized)
            if (
                path.is_absolute()
                or ".." in path.parts
                or not normalized
                or normalized in names
                or _is_symlink(entry)
            ):
                raise ArchiveError(f"Archive contains unsafe entry: {entry.filename}")
            names.add(normalized)
            total += entry.file_size
            if total > max_extracted:
                raise ArchiveError("Archive exceeds extracted size limit")
        if "manifest.json" not in names:
            raise ArchiveError("Archive lacks manifest.json")
        try:
            manifest = json.loads(archive.read("manifest.json").decode("utf-8"))
        except (KeyError, UnicodeError, ValueError) as error:
            raise ArchiveError(f"Invalid manifest: {error}") from error
        product = str(manifest.get("product", "explorer")).strip().lower()
        if product not in SUPPORTED_SCHEMAS:
            raise ArchiveError("Unsupported Lithica product")
        if manifest.get("syncSchema") != SUPPORTED_SCHEMAS[product]:
            raise ArchiveError("Unsupported synchronization schema")
        geopackage_name = "map.gpkg" if product == "mapper" else "observations.gpkg"
        if geopackage_name not in names:
            raise ArchiveError(f"Archive lacks {geopackage_name}")
        project_id = str(manifest.get("projectId", "")).strip()
        project_name = str(manifest.get("projectName", "")).strip()
        if not project_id or not project_name:
            raise ArchiveError("Manifest lacks project identity")
        if destination.exists():
            shutil.rmtree(destination)
        destination.mkdir(parents=True)
        archive.extractall(destination)
    return ExtractedProject(
        project_id=project_id,
        project_name=project_name,
        root=destination,
        geopackage=destination / geopackage_name,
        product=product,
    )


def _is_symlink(entry: zipfile.ZipInfo) -> bool:
    return ((entry.external_attr >> 16) & 0o170000) == 0o120000
