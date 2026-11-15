from django.db import connection, DatabaseError
from django.http import JsonResponse
from django.shortcuts import render
from .models import PageVisit


def home(request):
    PageVisit.objects.create()  # Demonstrates an actual PostgreSQL write.
    return render(request, "home.html", {"visits": PageVisit.objects.count()})


def live(request):
    return JsonResponse({"status": "ok"})


def health(request):
    restricted_role = False
    try:
        with connection.cursor() as cursor:
            cursor.execute("SELECT 1")
            database_ok = cursor.fetchone()[0] == 1
            cursor.execute("""
                SELECT to_regclass('public.core_pagevisit') IS NOT NULL,
                       (SELECT NOT rolsuper AND NOT rolcreaterole AND NOT rolcreatedb
                        FROM pg_roles WHERE rolname = current_user)
                       AND NOT EXISTS (
                           SELECT 1 FROM pg_roles r
                           WHERE r.rolname = 'rds_superuser'
                             AND pg_has_role(current_user, r.oid, 'MEMBER')
                       )
            """)
            schema_ready, restricted_role = cursor.fetchone()
            database_ok = database_ok and bool(schema_ready)
    except DatabaseError:
        database_ok = False
    return JsonResponse({"status": "ok" if database_ok else "unavailable",
                         "database": "postgresql", "connected": database_ok, "restricted_role": bool(restricted_role)},
                        status=200 if database_ok else 503)
