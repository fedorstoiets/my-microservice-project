from django.contrib import admin
from django.urls import path
from core import views

urlpatterns = [
    path("", views.home, name="home"),
    path("health/", views.health, name="health"),
    path("live/", views.live, name="live"),
    path("admin/", admin.site.urls),
]
