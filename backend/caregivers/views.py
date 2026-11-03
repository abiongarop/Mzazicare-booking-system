
from rest_framework import viewsets
from rest_framework.permissions import IsAuthenticated

from recommendations.firebase_authentication import FirebaseAuthentication

from .models import Caregiver, Service
from .serializers import CaregiverSerializer, ServiceSerializer


class CaregiverViewSet(viewsets.ReadOnlyModelViewSet):
    """
    Return caregiver information to authenticated users.
    """

    queryset = (
        Caregiver.objects
        .select_related("location")
        .prefetch_related("skills", "services")
    )

    serializer_class = CaregiverSerializer
    authentication_classes = [FirebaseAuthentication]
    permission_classes = [IsAuthenticated]


class ServiceViewSet(viewsets.ReadOnlyModelViewSet):
    """
    Return services available for booking.

    Optional query parameter:
        ?caregiver=75

    When supplied, only services offered by that caregiver
    and belonging to a verified caregiver are returned.
    """

    serializer_class = ServiceSerializer
    authentication_classes = [FirebaseAuthentication]
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        queryset = Service.objects.all().order_by("name")

        caregiver_id = self.request.query_params.get("caregiver")

        if caregiver_id:
            if not caregiver_id.isdigit():
                return Service.objects.none()

            queryset = queryset.filter(
                caregivers__id=int(caregiver_id),
                caregivers__is_verified=True,
            )

        return queryset.distinct()
