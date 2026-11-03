
from rest_framework.routers import DefaultRouter

from .views import CaregiverViewSet, ServiceViewSet

router = DefaultRouter()

router.register(
    "caregivers",
    CaregiverViewSet,
    basename="caregiver",
)

router.register(
    "services",
    ServiceViewSet,
    basename="service",
)

urlpatterns = router.urls
