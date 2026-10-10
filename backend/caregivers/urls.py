
from rest_framework.routers import DefaultRouter
from .views import CaregiverViewSet

router = DefaultRouter()
router.register("caregivers", CaregiverViewSet, basename="caregiver")

urlpatterns = router.urls