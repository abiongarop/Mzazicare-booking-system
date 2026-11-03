
from django.db import transaction
from django.shortcuts import get_object_or_404
from django.utils import timezone

from rest_framework import status
from rest_framework.exceptions import PermissionDenied, ValidationError
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from recommendations.firebase_authentication import FirebaseAuthentication
from accounts.models import MzaziCareProfile
from clients.models import FamilyCareProfile
from caregivers.models import Caregiver

from .models import CareSchedule, Conversation, Message, CareUpdate
from .serializers import (
    CareScheduleSerializer,
    ConversationSerializer,
    MessageSerializer,
    CareUpdateSerializer,
)


ACTIVE_BOOKING_STATUSES = ("pending", "confirmed", "in_progress")


class SecureAPIView(APIView):
    authentication_classes = [FirebaseAuthentication]
    permission_classes = [IsAuthenticated]

    def get_account(self, request):
        uid = getattr(request.user, "uid", None)

        if not uid:
            raise PermissionDenied(
                "Firebase user identity is unavailable."
            )

        account = MzaziCareProfile.objects.filter(
            firebase_uid=uid
        ).first()

        if account is None:
            raise PermissionDenied(
                "Complete your MzaziCare profile first."
            )

        return account

    def get_family(self, request):
        account = self.get_account(request)

        if account.role != "client":
            raise PermissionDenied("Family access is required.")

        family = FamilyCareProfile.objects.filter(
            account=account
        ).first()

        if family is None:
            raise ValidationError(
                "Complete your family care profile first."
            )

        return family

    def get_caregiver(self, request):
        account = self.get_account(request)

        if account.role != "caregiver":
            raise PermissionDenied("Caregiver access is required.")

        caregiver = Caregiver.objects.filter(
            account=account
        ).first()

        if caregiver is None:
            raise ValidationError(
                "Complete your caregiver profile first."
            )

        return caregiver


# ---------------------------------------------------------------------
# CARE SCHEDULES / BOOKINGS
# ---------------------------------------------------------------------

class CareScheduleListCreateView(SecureAPIView):

    def get(self, request):
        account = self.get_account(request)

        if account.role == "client":
            family = self.get_family(request)
            schedules = CareSchedule.objects.filter(
                family_profile=family
            )

        elif account.role == "caregiver":
            caregiver = self.get_caregiver(request)
            schedules = CareSchedule.objects.filter(
                caregiver=caregiver
            )

        else:
            raise PermissionDenied("Unsupported account role.")

        schedules = schedules.select_related(
            "family_profile",
            "family_profile__account",
            "caregiver",
            "caregiver__account",
        ).order_by("scheduled_start")

        return Response({
            "schedules": CareScheduleSerializer(
                schedules,
                many=True,
            ).data
        })

    def post(self, request):
        # Only a family/client can create a booking.
        family = self.get_family(request)

        # Validate input before using any submitted values.
        serializer = CareScheduleSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        data = serializer.validated_data
        caregiver = data.get("caregiver")
        start = data.get("scheduled_start")
        end = data.get("scheduled_end")
        services = data.get("services", [])

        if caregiver is None:
            raise ValidationError({
                "caregiver": "Select a recommended caregiver."
            })

        # A recommendation does not override verification.
        if not caregiver.is_verified:
            raise ValidationError({
                "caregiver": "The selected caregiver is not verified."
            })

        if not caregiver.availability:
            raise ValidationError({
                "caregiver": "The selected caregiver is not available."
            })

        if start is None or end is None:
            raise ValidationError({
                "scheduled_start": (
                    "Start and end times are required."
                )
            })

        if timezone.is_naive(start) or timezone.is_naive(end):
            raise ValidationError({
                "scheduled_start": (
                    "Provide timezone-aware start and end times."
                )
            })

        if start <= timezone.now():
            raise ValidationError({
                "scheduled_start": "Choose a future start time."
            })

        if end <= start:
            raise ValidationError({
                "scheduled_end": (
                    "End time must be later than the start time."
                )
            })

        # Require at least one service, and ensure the caregiver
        # actually provides every selected service.
        if not isinstance(services, list) or not services:
            raise ValidationError({
                "services": "Select at least one care service."
            })

        try:
            requested_service_ids = {
                int(service_id) for service_id in services
            }
        except (TypeError, ValueError):
            raise ValidationError({
                "services": "Provide valid service IDs."
            })

        if len(requested_service_ids) != len(services):
            raise ValidationError({
                "services": "Duplicate service IDs are not allowed."
            })

        provided_service_ids = set(
            caregiver.services.values_list("pk", flat=True)
        )

        if not requested_service_ids.issubset(
            provided_service_ids
        ):
            raise ValidationError({
                "services": (
                    "The caregiver does not provide all selected services."
                )
            })

        # Check conflicts and create the booking in one transaction.
        # select_for_update helps serialize competing booking requests
        # on databases that support row-level locking.
        with transaction.atomic():
            locked_caregiver = (
                Caregiver.objects.select_for_update()
                .filter(pk=caregiver.pk)
                .first()
            )

            if (
                locked_caregiver is None
                or not locked_caregiver.is_verified
                or not locked_caregiver.availability
            ):
                raise ValidationError({
                    "caregiver": (
                        "The caregiver is no longer available for booking."
                    )
                })

            conflict = CareSchedule.objects.filter(
                caregiver=locked_caregiver,
                scheduled_start__lt=end,
                scheduled_end__gt=start,
                status__in=ACTIVE_BOOKING_STATUSES,
            ).exists()

            if conflict:
                raise ValidationError({
                    "scheduled_start": (
                        "The caregiver already has a booking "
                        "during this period. Choose another time "
                        "or caregiver."
                    )
                })

            schedule = serializer.save(
                family_profile=family,
                caregiver=locked_caregiver,
                status="pending",
                services=sorted(requested_service_ids),
            )

        schedule = CareSchedule.objects.select_related(
            "family_profile",
            "family_profile__account",
            "caregiver",
            "caregiver__account",
        ).get(pk=schedule.pk)

        return Response(
            CareScheduleSerializer(schedule).data,
            status=status.HTTP_201_CREATED,
        )


class CareScheduleDetailView(SecureAPIView):

    def get_schedule(self, request, pk):
        account = self.get_account(request)

        if account.role == "client":
            family = self.get_family(request)
            queryset = CareSchedule.objects.filter(
                family_profile=family
            )

        elif account.role == "caregiver":
            caregiver = self.get_caregiver(request)
            queryset = CareSchedule.objects.filter(
                caregiver=caregiver
            )

        else:
            raise PermissionDenied("Unsupported account role.")

        return get_object_or_404(
            queryset.select_related(
                "family_profile",
                "family_profile__account",
                "caregiver",
                "caregiver__account",
            ),
            pk=pk,
        )

    def get(self, request, pk):
        schedule = self.get_schedule(request, pk)

        return Response(
            CareScheduleSerializer(schedule).data
        )

    def patch(self, request, pk):
        schedule = self.get_schedule(request, pk)
        account = self.get_account(request)

        if schedule.status in ("completed", "cancelled"):
            raise ValidationError(
                "Completed or cancelled bookings cannot be changed."
            )

        # Caregivers may update status only.
        if account.role == "caregiver":
            if set(request.data.keys()) != {"status"}:
                raise PermissionDenied(
                    "Caregivers can only update booking status."
                )

            transitions = {
                "pending": {"confirmed", "cancelled"},
                "confirmed": {"in_progress", "cancelled"},
                "in_progress": {"completed"},
            }

            new_status = request.data.get("status")

            if new_status not in transitions.get(
                schedule.status, set()
            ):
                raise ValidationError({
                    "status": (
                        f"Cannot change status from "
                        f"'{schedule.status}' to '{new_status}'."
                    )
                })

            schedule.status = new_status
            schedule.save(
                update_fields=["status", "updated_at"]
            )

            return Response(
                CareScheduleSerializer(schedule).data
            )

        # Family members can edit pending bookings only.
        if account.role != "client":
            raise PermissionDenied("Unsupported account role.")

        if schedule.status != "pending":
            raise ValidationError(
                "Only pending bookings can be edited by the family."
            )

        # Do not let the family change ownership or status.
        forbidden_fields = {
            "family_profile",
            "status",
            "cancellation_reason",
            "id",
            "created_at",
            "updated_at",
        }

        if forbidden_fields.intersection(request.data.keys()):
            raise ValidationError(
                "Ownership and booking status fields cannot be edited here."
            )

        serializer = CareScheduleSerializer(
            schedule,
            data=request.data,
            partial=True,
        )
        serializer.is_valid(raise_exception=True)

        caregiver = serializer.validated_data.get(
            "caregiver", schedule.caregiver
        )

        start = serializer.validated_data.get(
            "scheduled_start", schedule.scheduled_start
        )
        end = serializer.validated_data.get(
            "scheduled_end", schedule.scheduled_end
        )
        services = serializer.validated_data.get(
            "services", schedule.services
        )

        if end <= start:
            raise ValidationError({
                "scheduled_end": (
                    "End time must be later than the start time."
                )
            })

        if start <= timezone.now():
            raise ValidationError({
                "scheduled_start": "Choose a future start time."
            })

        if caregiver is None or not caregiver.is_verified:
            raise ValidationError({
                "caregiver": "Choose a verified caregiver."
            })

        if not caregiver.availability:
            raise ValidationError({
                "caregiver": "The caregiver is not available."
            })

        try:
            requested_service_ids = {
                int(service_id) for service_id in services
            }
        except (TypeError, ValueError):
            raise ValidationError({
                "services": "Provide valid service IDs."
            })

        if not requested_service_ids:
            raise ValidationError({
                "services": "Select at least one care service."
            })

        provided_service_ids = set(
            caregiver.services.values_list("pk", flat=True)
        )

        if not requested_service_ids.issubset(
            provided_service_ids
        ):
            raise ValidationError({
                "services": (
                    "The caregiver does not provide all selected services."
                )
            })

        with transaction.atomic():
            Caregiver.objects.select_for_update().get(
                pk=caregiver.pk
            )

            conflict = CareSchedule.objects.filter(
                caregiver=caregiver,
                scheduled_start__lt=end,
                scheduled_end__gt=start,
                status__in=ACTIVE_BOOKING_STATUSES,
            ).exclude(pk=schedule.pk).exists()

            if conflict:
                raise ValidationError({
                    "scheduled_start": (
                        "The caregiver already has a booking "
                        "during this period."
                    )
                })

            serializer.save(
                services=sorted(requested_service_ids)
            )

        return Response(
            CareScheduleSerializer(schedule).data
        )


class CancelCareScheduleView(SecureAPIView):

    def post(self, request, pk):
        family = self.get_family(request)

        with transaction.atomic():
            schedule = get_object_or_404(
                CareSchedule.objects.select_for_update(),
                pk=pk,
                family_profile=family,
            )

            if schedule.status in ("completed", "cancelled"):
                raise ValidationError(
                    "This booking cannot be cancelled."
                )

            schedule.status = "cancelled"
            schedule.cancellation_reason = str(
                request.data.get("reason", "")
            ).strip()[:2000]

            schedule.save(
                update_fields=[
                    "status",
                    "cancellation_reason",
                    "updated_at",
                ]
            )

        return Response(
            CareScheduleSerializer(schedule).data
        )


# ---------------------------------------------------------------------
# CONVERSATIONS
# ---------------------------------------------------------------------

class ConversationListCreateView(SecureAPIView):

    def get(self, request):
        account = self.get_account(request)

        if account.role == "client":
            family = self.get_family(request)
            conversations = Conversation.objects.filter(
                family_profile=family
            )

        elif account.role == "caregiver":
            caregiver = self.get_caregiver(request)
            conversations = Conversation.objects.filter(
                caregiver=caregiver
            )

        else:
            raise PermissionDenied("Unsupported account role.")

        conversations = conversations.select_related(
            "family_profile",
            "family_profile__account",
            "caregiver",
            "caregiver__account",
        )

        return Response({
            "conversations": ConversationSerializer(
                conversations,
                many=True,
            ).data
        })

    def post(self, request):
        family = self.get_family(request)
        caregiver_id = request.data.get("caregiver_id")

        if not caregiver_id:
            raise ValidationError({
                "caregiver_id": "This field is required."
            })

        caregiver = get_object_or_404(
            Caregiver,
            caregiver_id=caregiver_id,
            is_verified=True,
        )

        conversation, created = Conversation.objects.get_or_create(
            family_profile=family,
            caregiver=caregiver,
        )

        return Response(
            ConversationSerializer(conversation).data,
            status=(
                status.HTTP_201_CREATED
                if created
                else status.HTTP_200_OK
            ),
        )


class ConversationMessagesView(SecureAPIView):

    def get_conversation(self, request, pk):
        account = self.get_account(request)

        if account.role == "client":
            family = self.get_family(request)
            queryset = Conversation.objects.filter(
                family_profile=family
            )

        elif account.role == "caregiver":
            caregiver = self.get_caregiver(request)
            queryset = Conversation.objects.filter(
                caregiver=caregiver
            )

        else:
            raise PermissionDenied("Unsupported account role.")

        return get_object_or_404(
            queryset,
            pk=pk,
        )

    def get(self, request, pk):
        conversation = self.get_conversation(request, pk)
        account = self.get_account(request)

        messages = conversation.messages.select_related(
            "sender_profile"
        ).all()

        messages.filter(
            read_at__isnull=True
        ).exclude(
            sender_profile=account
        ).update(
            read_at=timezone.now()
        )

        return Response({
            "messages": MessageSerializer(
                messages,
                many=True,
            ).data
        })

    def post(self, request, pk):
        conversation = self.get_conversation(request, pk)
        account = self.get_account(request)

        serializer = MessageSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        message = serializer.save(
            conversation=conversation,
            sender_profile=account,
        )

        conversation.updated_at = timezone.now()
        conversation.save(update_fields=["updated_at"])

        return Response(
            MessageSerializer(message).data,
            status=status.HTTP_201_CREATED,
        )


# ---------------------------------------------------------------------
# CARE UPDATES
# ---------------------------------------------------------------------

class CareUpdateListCreateView(SecureAPIView):

    def get(self, request):
        account = self.get_account(request)

        if account.role == "client":
            family = self.get_family(request)
            updates = CareUpdate.objects.filter(
                schedule__family_profile=family
            )

        elif account.role == "caregiver":
            caregiver = self.get_caregiver(request)
            updates = CareUpdate.objects.filter(
                schedule__caregiver=caregiver
            )

        else:
            raise PermissionDenied("Unsupported account role.")

        updates = updates.select_related(
            "schedule",
            "schedule__family_profile",
            "schedule__caregiver",
            "author_profile",
        )

        return Response({
            "updates": CareUpdateSerializer(
                updates,
                many=True,
            ).data
        })

    def post(self, request):
        caregiver = self.get_caregiver(request)

        schedule_id = request.data.get("schedule_id")

        if not schedule_id:
            raise ValidationError({
                "schedule_id": "This field is required."
            })

        schedule = get_object_or_404(
            CareSchedule,
            pk=schedule_id,
            caregiver=caregiver,
        )

        if schedule.status not in ("in_progress", "completed"):
            raise ValidationError(
                "Care updates can only be recorded for visits "
                "in progress or completed."
            )

        serializer = CareUpdateSerializer(data={
            **request.data,
            "schedule": schedule.pk,
        })
        serializer.is_valid(raise_exception=True)

        update = serializer.save(
            schedule=schedule,
            author_profile=caregiver.account,
        )

        return Response(
            CareUpdateSerializer(update).data,
            status=status.HTTP_201_CREATED,
        )


class CareUpdateDetailView(SecureAPIView):

    def get(self, request, pk):
        account = self.get_account(request)

        if account.role == "client":
            family = self.get_family(request)
            queryset = CareUpdate.objects.filter(
                schedule__family_profile=family
            )

        elif account.role == "caregiver":
            caregiver = self.get_caregiver(request)
            queryset = CareUpdate.objects.filter(
                schedule__caregiver=caregiver
            )

        else:
            raise PermissionDenied("Unsupported account role.")

        update = get_object_or_404(
            queryset.select_related(
                "schedule",
                "author_profile",
            ),
            pk=pk,
        )

        return Response(
            CareUpdateSerializer(update).data
        )
