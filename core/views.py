from django.db import connection
from django.http import JsonResponse
from django.shortcuts import render
from .models import PageVisit


def home(request):
    PageVisit.objects.create()  # Demonstrates an actual PostgreSQL write.
    return render(request, "home.html", {"visits": PageVisit.objects.count()})


def health(request):
    with connection.cursor() as cursor:
        cursor.execute("SELECT 1")
        database_ok = cursor.fetchone()[0] == 1
    return JsonResponse({"status": "ok", "database": "postgresql", "connected": database_ok})
