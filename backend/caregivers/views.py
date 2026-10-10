
from rest_framework import viewsets
from .models import Caregiver
from .serializers import CaregiverSerializer


class CaregiverViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = Caregiver.objects.select_related(
        "location"
    ).prefetch_related("skills", "services")
    serializer_class = CaregiverSerializer