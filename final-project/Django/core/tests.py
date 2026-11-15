from unittest.mock import patch, MagicMock
from django.db import DatabaseError
from django.test import SimpleTestCase, override_settings
from django.urls import reverse


@override_settings(ALLOWED_HOSTS=["testserver"], SECURE_SSL_REDIRECT=False)
class HealthTests(SimpleTestCase):
    def test_routes(self):
        self.assertEqual(reverse("home"), "/")
        self.assertEqual(reverse("health"), "/health/")
        self.assertEqual(reverse("live"), "/live/")

    def test_liveness_does_not_use_database(self):
        with patch("core.views.connection") as database:
            database.cursor.side_effect = DatabaseError
            self.assertEqual(self.client.get("/live/").status_code, 200)

    def test_database_outage_returns_503_without_details(self):
        with patch("core.views.connection") as database:
            database.cursor.side_effect = DatabaseError("private details")
            response = self.client.get("/health/")
        self.assertEqual(response.status_code, 503)
        self.assertFalse(response.json()["connected"])
        self.assertNotIn("private details", response.content.decode())

    def test_database_readiness(self):
        cursor = MagicMock()
        cursor.__enter__.return_value.fetchone.return_value = (1, True)
        with patch("core.views.connection") as database:
            database.cursor.return_value = cursor
            response = self.client.get("/health/")
        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.json()["connected"])
