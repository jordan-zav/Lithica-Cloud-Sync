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
import struct
import urllib.error
import urllib.parse
import urllib.request
import zlib
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
        result = []
        for folder_name in FOLDER_NAMES:
            folder_query = (
                "'root' in parents and "
                "mimeType='application/vnd.google-apps.folder' "
                f"and name='{folder_name}' and trashed=false"
            )
            folders = self._list(access_token, folder_query, "files(id)")
            if not folders:
                continue
            product = "mapper" if folder_name == "Lithica Mapper" else "explorer"
            for folder in folders:
                query = (
                    f"'{folder['id']}' in parents and trashed=false "
                    "and mimeType='application/zip'"
                )
                rows = self._list(
                    access_token,
                    query,
                    "nextPageToken,files(id,name,modifiedTime,size,md5Checksum,appProperties)",
                )
                for row in rows:
                    name = str(row.get("name", ""))
                    if not name.startswith(PROJECT_PREFIX) or not name.endswith(".zip"):
                        continue
                    project_name = (row.get("appProperties") or {}).get(
                        "projectName"
                    )
                    if not project_name:
                        project_name = self._read_manifest_name(
                            access_token, str(row["id"])
                        )
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
                            project_name=project_name,
                        )
                    )
        return sorted(result, key=lambda item: item.modified_time, reverse=True)

    def _read_manifest_name(self, access_token: str, file_id: str) -> str | None:
        url = f"https://www.googleapis.com/drive/v3/files/{file_id}?alt=media"
        request = urllib.request.Request(
            url,
            headers={
                "Authorization": f"Bearer {access_token}",
                "Range": "bytes=0-131071",
            },
            method="GET",
        )
        try:
            with self._opener(request, timeout=self._timeout) as response:
                payload = response.read(131072)
            manifest = _manifest_from_zip_prefix(payload)
            name = str(manifest.get("projectName", "")).strip()
            return name or None
        except (OSError, ValueError, KeyError, struct.error, urllib.error.HTTPError):
            return None

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


def _manifest_from_zip_prefix(payload: bytes) -> dict:
    offset = 0
    while offset + 30 <= len(payload):
        header = struct.unpack_from("<IHHHHHIIIHH", payload, offset)
        signature, flags, compression = header[0], header[2], header[3]
        compressed_size, name_length, extra_length = header[7], header[9], header[10]
        if signature != 0x04034B50 or flags & 0x01 or flags & 0x08:
            break
        name_start = offset + 30
        data_start = name_start + name_length + extra_length
        data_end = data_start + compressed_size
        if data_end > len(payload):
            break
        encoding = "utf-8" if flags & 0x800 else "cp437"
        name = payload[name_start : name_start + name_length].decode(encoding)
        if name == "manifest.json":
            compressed = payload[data_start:data_end]
            if compression == 0:
                raw = compressed
            elif compression == 8:
                raw = zlib.decompress(compressed, -zlib.MAX_WBITS)
            else:
                raise ValueError("Unsupported manifest compression")
            return json.loads(raw.decode("utf-8"))
        offset = data_end
    raise ValueError("manifest.json is not available in the ZIP prefix")
