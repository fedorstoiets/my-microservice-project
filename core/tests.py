from unittest.mock import patch
from django.test import SimpleTestCase
from django.urls import reverse


class HomeRouteTests(SimpleTestCase):
    def test_url_names_resolve(self):
        self.assertEqual(reverse("home"), "/")
        self.assertEqual(reverse("health"), "/health/")
