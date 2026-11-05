from django.urls import path
from rest_framework.routers import DefaultRouter

from .views import CaregiverViewSet, ServiceViewSet, CaregiverProfileView

router = DefaultRouter()
router.register("caregivers", CaregiverViewSet, basename="caregiver")
router.register("services", ServiceViewSet, basename="service")

urlpatterns = [
    path(
        "caregiver-profile/",
        CaregiverProfileView.as_view(),
        name="caregiver-profile",
    ),
]

urlpatterns += router.urls