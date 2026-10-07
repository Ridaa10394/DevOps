import pytest

from src.app import create_app


@pytest.fixture
def client():
    app = create_app()
    app.config["TESTING"] = True
    return app.test_client()


def test_index(client):
    resp = client.get("/")
    assert resp.status_code == 200
    assert resp.get_json()["app"] == "devops-s16-app"


def test_health(client):
    resp = client.get("/health")
    assert resp.status_code == 200
    assert resp.get_json()["status"] == "ok"


def test_calc_add(client):
    resp = client.get("/calc/add?a=2&b=3")
    assert resp.status_code == 200
    assert resp.get_json()["result"] == 5


def test_calc_divide_by_zero(client):
    resp = client.get("/calc/divide?a=1&b=0")
    assert resp.status_code == 400


def test_calc_bad_input(client):
    resp = client.get("/calc/add?a=x&b=1")
    assert resp.status_code == 400


def test_calc_unknown_op(client):
    resp = client.get("/calc/power?a=2&b=3")
    assert resp.status_code == 404
