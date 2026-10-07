import os
os.environ["DATABASE_URL"] = "sqlite:///./test.db"

from fastapi.testclient import TestClient
from app.main import app

import pytest

client = TestClient(app)

@pytest.fixture(scope="module", autouse=True)
def _run_startup():
    # Fix: TestClient only runs FastAPI's startup event (create_all -> tasks table)
    # when used as a context manager. Without this the POST test hit
    # "sqlite3.OperationalError: no such table: tasks".
    with client:
        yield

def test_health():
    assert client.get("/health").json() == {"status": "UP"}

def test_root():
    response = client.get("/")
    assert response.status_code == 200
    assert response.json()["service"] == "TaskBoard API"

def test_create_task_validation():
    response = client.post("/api/tasks", json={"title": "Deploy application", "priority": "HIGH", "assignee": "Student"})
    assert response.status_code == 201
    assert response.json()["title"] == "Deploy application"
