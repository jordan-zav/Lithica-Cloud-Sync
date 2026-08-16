import json
import urllib.parse

from lithica_drive_sync.drive_client import DriveClient


class FakeResponse:
    def __init__(self, payload=b"", status=200, headers=None):
        self._payload = payload
        self.status = status
        self.headers = headers or {}

    def read(self, size=-1):
        return self._payload if size == -1 else self._payload[:size]

    def __enter__(self):
        return self

    def __exit__(self, *args):
        return False


def test_lists_only_lithica_zip_files():
    calls = []
    responses = iter(
        [
            FakeResponse(
                json.dumps(
                    {
                        "files": [
                            {"id": "explorer-folder", "name": "Lithica Explorer"},
                            {"id": "mapper-folder", "name": "Lithica Mapper"},
                        ]
                    }
                ).encode()
            ),
            FakeResponse(
                json.dumps(
                    {
                        "files": [
                            {
                                "id": "f1",
                                "name": "lithica-project-p1.zip",
                                "modifiedTime": "2026-06-27T10:00:00Z",
                                "size": "10",
                                "md5Checksum": "abc",
                                "parents": ["explorer-folder"],
                                "appProperties": {"projectName": "Project One"},
                            },
                            {
                                "id": "f2",
                                "name": "lithica-project-m1.zip",
                                "modifiedTime": "2026-06-28T10:00:00Z",
                                "size": "20",
                                "md5Checksum": "def",
                                "parents": ["mapper-folder"],
                                "appProperties": {"projectName": "Regional Map"},
                            },
                            {
                                "id": "f3",
                                "name": "lithica-project-legacy.zip",
                                "modifiedTime": "2026-06-26T10:00:00Z",
                                "size": "30",
                                "parents": ["explorer-folder"],
                            },
                        ]
                    }
                ).encode()
            ),
        ]
    )

    def opener(request, timeout):
        calls.append(request.full_url)
        return next(responses)

    files = DriveClient(opener=opener).list_projects("token")

    assert [item.name for item in files] == [
        "lithica-project-m1.zip",
        "lithica-project-p1.zip",
        "lithica-project-legacy.zip",
    ]
    assert [item.source_product for item in files] == [
        "mapper",
        "explorer",
        "explorer",
    ]
    assert [item.project_name for item in files] == [
        "Regional Map",
        "Project One",
        None,
    ]
    assert len(calls) == 2
    assert all("upload" not in url for url in calls)
    assert all("alt=media" not in url for url in calls)

    folder_query = urllib.parse.parse_qs(
        urllib.parse.urlparse(calls[0]).query
    )["q"][0]
    file_query = urllib.parse.parse_qs(
        urllib.parse.urlparse(calls[1]).query
    )["q"][0]
    assert "Lithica Explorer" in folder_query
    assert "Lithica Mapper" in folder_query
    assert "'explorer-folder' in parents" in file_query
    assert "'mapper-folder' in parents" in file_query
