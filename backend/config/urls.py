
from django.contrib import admin
from django.http import JsonResponse
from django.urls import include, path


def home(request):
    return JsonResponse({
        "project": "MzaziCare",
        "status": "success",
        "message": "MzaziCare backend is running!",
    })


urlpatterns = [
    path("", home, name="home"),
    path("admin/", admin.site.urls),
    path("api/", include("caregivers.urls")),
    path("api/", include("clients.urls")),
    path("api/", include("bookings.urls")),
]