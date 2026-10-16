
from django.contrib import admin
from django.http import JsonResponse
from django.urls import include, path
from recommendations.firebase_views import FirebaseAuthCheckView
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
    path("api/recommendations/", include("recommendations.urls")),
    path(
    "api/auth/check/",
    FirebaseAuthCheckView.as_view(),
    name="firebase-auth-check",
),
    path("api/profile/", include("accounts.urls")),
]