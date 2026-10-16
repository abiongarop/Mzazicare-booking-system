from django.urls import include, path
from rest_framework.routers import DefaultRouter

from .views import ClientViewSet, FamilyCareProfileView

router = DefaultRouter()
router.register("clients", ClientViewSet, basename="client")

urlpatterns = [
    path(
        "family-profile/",
        FamilyCareProfileView.as_view(),
        name="family-care-profile",
    ),
    *router.urls,
]