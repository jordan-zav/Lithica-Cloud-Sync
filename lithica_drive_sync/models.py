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

from dataclasses import dataclass
from datetime import datetime
from pathlib import Path


@dataclass(frozen=True)
class ProjectFile:
    id: str
    name: str
    modified_time: datetime
    size: int
    md5_checksum: str | None = None
    source_product: str = "explorer"
    project_name: str | None = None


@dataclass(frozen=True)
class ExtractedProject:
    project_id: str
    project_name: str
    root: Path
    geopackage: Path
    product: str = "explorer"
