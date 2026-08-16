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

import unicodedata

from .config import PROJECT_PREFIX
from .models import ProjectFile


def display_name(project: ProjectFile) -> str:
    if project.project_name:
        return project.project_name
    name = project.name
    if name.startswith(PROJECT_PREFIX):
        name = name[len(PROJECT_PREFIX) :]
    if name.lower().endswith(".zip"):
        name = name[:-4]
    return name or project.name


def _search_text(value: object) -> str:
    normalized = unicodedata.normalize("NFKD", str(value).casefold())
    return "".join(char for char in normalized if not unicodedata.combining(char))


class ProjectCatalog:
    def __init__(self):
        self._projects: tuple[ProjectFile, ...] = ()
        self._search_rows: tuple[tuple[ProjectFile, str], ...] = ()

    def replace(self, projects) -> None:
        self._projects = tuple(projects)
        self._search_rows = tuple(
            (
                project,
                _search_text(
                    " ".join(
                        (
                            display_name(project),
                            project.name,
                            project.id,
                            project.source_product,
                        )
                    )
                ),
            )
            for project in self._projects
        )

    def clear(self) -> None:
        self.replace(())

    def all(self) -> list[ProjectFile]:
        return list(self._projects)

    def search(self, query: str) -> list[ProjectFile]:
        terms = _search_text(query).split()
        if not terms:
            return self.all()
        return [
            project
            for project, searchable in self._search_rows
            if all(term in searchable for term in terms)
        ]
