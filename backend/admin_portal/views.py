from caregivers.views import sync_caregiver_after_commit
from django.db import transaction
from django.utils import timezone

from recommendations.graph_service import sync_caregiver_to_neo4j

from rest_framework import status
from rest_framework.exceptions import PermissionDenied, ValidationError
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from recommendations.firebase_authentication import FirebaseAuthentication
from accounts.models import MzaziCareProfile
from caregivers.models import Caregiver
from clients.models import FamilyCareProfile
from care_coordination.models import CareSchedule

from .serializers import (
    AdminCaregiverSerializer,
    AdminFamilySerializer,
    AdminCareScheduleSerializer,
)


ACTIVE_STATUSES = ("pending", "confirmed", "in_progress")


class AdminAPIView(APIView):
    authentication_classes = [FirebaseAuthentication]
    permission_classes = [IsAuthenticated]

    def get_admin_account(self, request):
        uid = getattr(request.user, "uid", None)

        if not uid:
            raise PermissionDenied("Firebase identity is unavailable.")

        account = MzaziCareProfile.objects.filter(
            firebase_uid=uid
        ).first()

        if account is None or account.role != "admin":
            raise PermissionDenied(
                "Administrator access is required."
            )

        return account


class AdminDashboardView(AdminAPIView):
    def get(self, request):
        self.get_admin_account(request)

        return Response({
            "total_caregivers": Caregiver.objects.count(),
            "verified_caregivers": Caregiver.objects.filter(
                is_verified=True
            ).count(),
            "pending_caregivers": Caregiver.objects.filter(
                is_verified=False
            ).count(),
            "total_families": FamilyCareProfile.objects.count(),
            "total_bookings": CareSchedule.objects.count(),
            "pending_bookings": CareSchedule.objects.filter(
                status="pending"
            ).count(),
            "active_bookings": CareSchedule.objects.filter(
                status__in=("confirmed", "in_progress")
            ).count(),
            "completed_bookings": CareSchedule.objects.filter(
                status="completed"
            ).count(),
        })


class AdminCaregiverListView(AdminAPIView):
    def get(self, request):
        self.get_admin_account(request)

        queryset = Caregiver.objects.select_related(
            "account", "location"
        ).prefetch_related(
            "skills", "services"
        ).order_by("-created_at")

        verification = request.query_params.get("verified")

        if verification == "true":
            queryset = queryset.filter(is_verified=True)
        elif verification == "false":
            queryset = queryset.filter(is_verified=False)

        return Response({
            "caregivers": AdminCaregiverSerializer(
                queryset,
                many=True,
            ).data
        })




class AdminCaregiverVerificationView(AdminAPIView):

    def patch(self, request, pk):
        self.get_admin_account(request)

        if set(request.data.keys()) != {"is_verified"}:
            raise ValidationError({
                "is_verified": (
                    "Submit only the is_verified field."
                )
            })

        value = request.data.get("is_verified")

        if not isinstance(value, bool):
            raise ValidationError({
                "is_verified": (
                    "This field must be true or false."
                )
            })

        with transaction.atomic():

            caregiver = Caregiver.objects.select_for_update().get(
                pk=pk
            )

            caregiver.is_verified = value

            caregiver.save(
                update_fields=["is_verified", "updated_at"]
            )

            # Synchronize Neo4j after PostgreSQL commits.
            transaction.on_commit(
                lambda caregiver_id=caregiver.pk:
                    sync_caregiver_after_commit(caregiver_id)
            )

        # Retrieve the updated caregiver for the response.
        caregiver = (
            Caregiver.objects
            .select_related("account", "location")
            .prefetch_related("skills", "services")
            .get(pk=pk)
        )

        return Response(
            AdminCaregiverSerializer(caregiver).data,
            status=status.HTTP_200_OK,
        )




class AdminFamilyListView(AdminAPIView):
    def get(self, request):
        self.get_admin_account(request)

        families = FamilyCareProfile.objects.select_related(
            "account"
        ).prefetch_related(
            "required_services", "required_skills"
        ).order_by("-created_at")

        return Response({
            "families": AdminFamilySerializer(
                families,
                many=True,
            ).data
        })


class AdminCareScheduleListCreateView(AdminAPIView):
    def get(self, request):
        self.get_admin_account(request)

        schedules = CareSchedule.objects.select_related(
            "family_profile",
            "family_profile__account",
            "caregiver",
            "caregiver__account",
        ).order_by("-scheduled_start")

        booking_status = request.query_params.get("status")
        if booking_status:
            schedules = schedules.filter(status=booking_status)

        return Response({
            "schedules": AdminCareScheduleSerializer(
                schedules,
                many=True,
            ).data
        })

    def post(self, request):
        self.get_admin_account(request)

        serializer = AdminCareScheduleSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        data = serializer.validated_data
        family = data.get("family_profile")
        caregiver = data.get("caregiver")
        start = data.get("scheduled_start")
        end = data.get("scheduled_end")
        services = data.get("services", [])

        if family is None:
            raise ValidationError({
                "family_profile": "Select a family."
            })

        if caregiver is None:
            raise ValidationError({
                "caregiver": "Select a caregiver."
            })

        if not caregiver.is_verified:
            raise ValidationError({
                "caregiver": "Only verified caregivers can be booked."
            })

        if not caregiver.availability:
            raise ValidationError({
                "caregiver": "This caregiver is not available."
            })

        if not start or not end:
            raise ValidationError(
                "A start time and end time are required."
            )

        if timezone.is_naive(start) or timezone.is_naive(end):
            raise ValidationError(
                "Provide timezone-aware start and end times."
            )

        if start <= timezone.now():
            raise ValidationError({
                "scheduled_start": "Choose a future date and time."
            })

        if end <= start:
            raise ValidationError({
                "scheduled_end": "End time must be after start time."
            })

        if not isinstance(services, list) or not services:
            raise ValidationError({
                "services": "Select at least one care service."
            })

        try:
            service_ids = {int(item) for item in services}
        except (TypeError, ValueError):
            raise ValidationError({
                "services": "Provide valid service IDs."
            })

        if len(service_ids) != len(services):
            raise ValidationError({
                "services": "Duplicate service IDs are not allowed."
            })

        provided_service_ids = set(
            caregiver.services.values_list("pk", flat=True)
        )

        if not service_ids.issubset(provided_service_ids):
            raise ValidationError({
                "services": (
                    "The caregiver does not provide all selected services."
                )
            })

        with transaction.atomic():
            locked_caregiver = Caregiver.objects.select_for_update().filter(
                pk=caregiver.pk
            ).first()

            if (
                locked_caregiver is None
                or not locked_caregiver.is_verified
                or not locked_caregiver.availability
            ):
                raise ValidationError({
                    "caregiver": (
                        "This caregiver is no longer eligible for booking."
                    )
                })

            conflict = CareSchedule.objects.filter(
                caregiver=locked_caregiver,
                scheduled_start__lt=end,
                scheduled_end__gt=start,
                status__in=ACTIVE_STATUSES,
            ).exists()

            if conflict:
                raise ValidationError({
                    "scheduled_start": (
                        "The caregiver already has a booking "
                        "during this period."
                    )
                })

            schedule = serializer.save(
                family_profile=family,
                caregiver=locked_caregiver,
                status="pending",
                services=sorted(service_ids),
            )

        schedule = CareSchedule.objects.select_related(
            "family_profile",
            "family_profile__account",
            "caregiver",
            "caregiver__account",
        ).get(pk=schedule.pk)

        return Response(
            AdminCareScheduleSerializer(schedule).data,
            status=status.HTTP_201_CREATED,
        )


class AdminCareScheduleStatusView(AdminAPIView):
    def patch(self, request, pk):
        self.get_admin_account(request)

        if set(request.data.keys()) != {"status"}:
            raise ValidationError({
                "status": "Submit only the status field."
            })

        allowed_statuses = {
            "pending",
            "confirmed",
            "in_progress",
            "completed",
            "cancelled",
        }

        new_status = request.data.get("status")

        if new_status not in allowed_statuses:
            raise ValidationError({
                "status": "Invalid booking status."
            })

        with transaction.atomic():
            schedule = CareSchedule.objects.select_for_update().get(
                pk=pk
            )

            schedule.status = new_status
            schedule.save(update_fields=["status", "updated_at"])

        return Response(
            AdminCareScheduleSerializer(schedule).data,
            status=status.HTTP_200_OK
        )
