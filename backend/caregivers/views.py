
import uuid

from django.db import transaction

from rest_framework import viewsets
from rest_framework.views import APIView
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.exceptions import PermissionDenied, ValidationError

from recommendations.firebase_authentication import FirebaseAuthentication
from recommendations.graph_service import sync_caregiver_to_neo4j

from accounts.models import MzaziCareProfile

from .models import Caregiver, Location, Skill, Service
from .serializers import CaregiverSerializer, ServiceSerializer


def sync_caregiver_after_commit(caregiver_id):
    """
    Fetch the committed caregiver record and synchronize it
    with Neo4j, including services, skills and location.
    """

    caregiver = (
        Caregiver.objects
        .select_related("location")
        .prefetch_related("skills", "services")
        .get(pk=caregiver_id)
    )

    sync_caregiver_to_neo4j(caregiver)


class CaregiverProfileView(APIView):
    authentication_classes = [FirebaseAuthentication]
    permission_classes = [IsAuthenticated]

    def get_account(self, request):
        firebase_uid = getattr(request.user, "uid", None)

        account = MzaziCareProfile.objects.filter(
            firebase_uid=firebase_uid
        ).first()

        if account is None:
            raise PermissionDenied(
                "Your MzaziCare account was not found."
            )

        if account.role != "caregiver":
            raise PermissionDenied(
                "Only caregiver accounts can access this profile."
            )

        return account

    def get(self, request):
        account = self.get_account(request)

        caregiver = Caregiver.objects.filter(
            account=account
        ).first()

        if caregiver is None:
            return Response({})

        serializer = CaregiverSerializer(caregiver)

        return Response(serializer.data)

    def post(self, request):
        return self.save_profile(request)

    def patch(self, request):
        return self.save_profile(request)

    @transaction.atomic
    def save_profile(self, request):
        account = self.get_account(request)

        caregiver = Caregiver.objects.filter(
            account=account
        ).first()

        data = request.data.copy()

        location_name = data.pop("location", None)
        skills = data.pop("skills", None)
        services = data.pop("services", None)

        # Create a new caregiver if one does not exist.
        if caregiver is None:

            if not location_name:
                raise ValidationError({
                    "location": "Location is required."
                })

            if not data.get("age"):
                raise ValidationError({
                    "age": "Age is required."
                })

            caregiver = Caregiver(
                account=account,
                caregiver_id=(
                    f"CG-{uuid.uuid4().hex[:10].upper()}"
                ),
                is_verified=False,
            )

        # Save caregiver location.
        if location_name:
            location, _ = Location.objects.get_or_create(
                name=location_name.strip()
            )

            caregiver.location = location

        # Validate and save caregiver details.
        serializer = CaregiverSerializer(
            caregiver,
            data=data,
            partial=True,
        )

        serializer.is_valid(raise_exception=True)

        caregiver = serializer.save()

        # Save caregiver skills.
        if skills is not None:
            skill_objects = [
                Skill.objects.get_or_create(
                    name=name.strip()
                )[0]
                for name in skills
                if isinstance(name, str) and name.strip()
            ]

            caregiver.skills.set(skill_objects)

        # Save caregiver services.
        if services is not None:
            service_objects = [
                Service.objects.get_or_create(
                    name=name.strip()
                )[0]
                for name in services
                if isinstance(name, str) and name.strip()
            ]

            caregiver.services.set(service_objects)

        caregiver.save()

        # Synchronize PostgreSQL data with Neo4j only after
        # the database transaction successfully commits.
        transaction.on_commit(
            lambda caregiver_id=caregiver.pk:
                sync_caregiver_after_commit(caregiver_id)
        )

        return Response(
            CaregiverSerializer(caregiver).data
        )


class CaregiverViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = (
        Caregiver.objects
        .select_related("location")
        .prefetch_related("skills", "services")
    )

    serializer_class = CaregiverSerializer
    authentication_classes = [FirebaseAuthentication]
    permission_classes = [IsAuthenticated]


class ServiceViewSet(viewsets.ReadOnlyModelViewSet):
    serializer_class = ServiceSerializer
    authentication_classes = [FirebaseAuthentication]
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        queryset = Service.objects.all().order_by("name")

        caregiver_id = self.request.query_params.get(
            "caregiver"
        )

        if caregiver_id:
            if not caregiver_id.isdigit():
                return Service.objects.none()

            queryset = queryset.filter(
                caregivers__id=int(caregiver_id),
                caregivers__is_verified=True,
            )

        return queryset.distinct()
