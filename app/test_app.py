from app import app


def test_index():
    response = app.test_client().get("/")
    assert response.status_code == 200
    assert b"Bienvenue" in response.data


def test_health():
    response = app.test_client().get("/health")
    assert response.status_code == 200
    assert response.get_json() == {"status": "ok"}


def test_version():
    response = app.test_client().get("/version")
    assert response.status_code == 200
    assert "version" in response.get_json()
