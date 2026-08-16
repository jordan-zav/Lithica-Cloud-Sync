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
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime
from pathlib import Path

from .config import FOLDER_NAMES, PROJECT_PREFIX
from .models import ProjectFile


class DriveError(RuntimeError):
    pass


class DriveClient:
    def __init__(self, opener=None, timeout=60):
        self._opener = opener or urllib.request.urlopen
        self._timeout = timeout

    def list_projects(self, access_token: str) -> list[ProjectFile]:
        folder_names = " or ".join(f"name='{name}'" for name in FOLDER_NAMES)
        folder_query = (
            "'root' in parents and "
            "mimeType='application/vnd.google-apps.folder' and "
            f"({folder_names}) and trashed=false"
        )
        folders = self._list(
            access_token,
            folder_query,
            "nextPageToken,files(id,name)",
        )
        folder_products = {
            str(folder["id"]): (
                "mapper" if folder.get("name") == "Lithica Mapper" else "explorer"
            )
            for folder in folders
            if folder.get("id") and folder.get("name") in FOLDER_NAMES
        }
        if not folder_products:
            return []

        parent_query = " or ".join(
            f"'{folder_id}' in parents" for folder_id in folder_products
        )
        file_query = (
            f"({parent_query}) and trashed=false "
            "and mimeType='application/zip'"
        )
        rows = self._list(
            access_token,
            file_query,
            "nextPageToken,files("
            "id,name,parents,modifiedTime,size,md5Checksum,appProperties)",
        )

        result = []
        for row in rows:
            name = str(row.get("name", ""))
            if not name.startswith(PROJECT_PREFIX) or not name.endswith(".zip"):
                continue
            product = next(
                (
                    folder_products[parent]
                    for parent in row.get("parents", [])
                    if parent in folder_products
                ),
                None,
            )
            if product is None:
                continue
            project_name = str(
                (row.get("appProperties") or {}).get("projectName", "")
            ).strip()
            result.append(
                ProjectFile(
                    id=str(row["id"]),
                    name=name,
                    modified_time=datetime.fromisoformat(
                        str(row["modifiedTime"]).replace("Z", "+00:00")
                    ),
                    size=int(row.get("size", 0)),
                    md5_checksum=row.get("md5Checksum"),
                    source_product=product,
                    project_name=project_name or None,
                )
            )
        return sorted(result, key=lambda item: item.modified_time, reverse=True)

    def download(self, access_token: str, file: ProjectFile, target: Path) -> Path:
        url = f"https://www.googleapis.com/drive/v3/files/{file.id}?alt=media"
        request = urllib.request.Request(
            url, headers={"Authorization": f"Bearer {access_token}"}, method="GET"
        )
        target = Path(target)
        target.parent.mkdir(parents=True, exist_ok=True)
        try:
            with self._opener(request, timeout=self._timeout) as response:
                with target.open("wb") as output:
                    while True:
                        chunk = response.read(1024 * 1024)
                        if not chunk:
                            break
                        output.write(chunk)
        except (OSError, urllib.error.HTTPError) as error:
            target.unlink(missing_ok=True)
            raise DriveError(f"Drive download failed: {error}") from error
        return target

    def _list(self, token: str, query: str, fields: str) -> list[dict]:
        rows = []
        page_token = None
        while True:
            params = {"q": query, "spaces": "drive", "fields": fields, "pageSize": 100}
            if page_token:
                params["pageToken"] = page_token
            url = "https://www.googleapis.com/drive/v3/files?" + urllib.parse.urlencode(
                params
            )
            request = urllib.request.Request(
                url, headers={"Authorization": f"Bearer {token}"}, method="GET"
            )
            try:
                with self._opener(request, timeout=self._timeout) as response:
                    payload = json.loads(response.read().decode("utf-8"))
            except (OSError, ValueError, urllib.error.HTTPError) as error:
                raise DriveError(f"Drive request failed: {error}") from error
            rows.extend(payload.get("files", []))
            page_token = payload.get("nextPageToken")
            if not page_token:
                return rows
