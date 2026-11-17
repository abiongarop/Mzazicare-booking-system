
from django.conf import settings
from django.core.mail import send_mail
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
from notifications.models import Notification

from .models import (
    CareSchedule,
    Conversation,
    Message,
    CareUpdate,
)

from .serializers import (
    CareScheduleSerializer,
    ConversationSerializer,
    MessageSerializer,
    CareUpdateSerializer,
)


# Pending requests reserve the requested time while awaiting a decision.
ACTIVE_BOOKING_STATUSES = (
    "pending",
    "confirmed",
    "in_progress",
)


# ---------------------------------------------------------------------
# EMAIL AND IN-APP NOTIFICATIONS
# ---------------------------------------------------------------------

def get_profile_email(profile):
    """Get an email address from a profile or its related account."""

    if profile is None:
        return None

    email = getattr(profile, "email", None)

    if email:
        return email

    account = getattr(profile, "account", None)

    if account:
        return getattr(account, "email", None)

    return None


def send_profile_email(profile, subject, message):
    """
    Send an email without interrupting the main operation
    if email delivery fails.
    """

    recipient = get_profile_email(profile)

    if not recipient:
        return

    try:
        send_mail(
            subject=subject,
            message=message,
            from_email=getattr(
                settings,
                "DEFAULT_FROM_EMAIL",
                None,
            ),
            recipient_list=[recipient],
            fail_silently=True,
        )
    except Exception:
        # Email failure must not undo a saved booking or message.
        pass


def notify_after_commit(profile, subject, message):
    """Send an email only after the database transaction succeeds."""

    transaction.on_commit(
        lambda p=profile, s=subject, m=message:
            send_profile_email(p, s, m)
    )


def create_in_app_notification(
    recipient,
    notification_type,
    title,
    body,
    schedule=None,
    conversation=None,
    message=None,
):
    """Create an in-app notification for a MzaziCare account."""

    if recipient is None:
        return None

    return Notification.objects.create(
        recipient=recipient,
        notification_type=notification_type,
        title=title,
        body=body,
        schedule=schedule,
        conversation=conversation,
        message=message,
    )


# ---------------------------------------------------------------------
# SHARED HELPERS
# ---------------------------------------------------------------------

def get_or_create_conversation(family, caregiver):
    """
    Reuse the existing conversation for a family-caregiver pair,
    or create one if it does not exist.
    """

    return Conversation.objects.get_or_create(
        family_profile=family,
        caregiver=caregiver,
    )


def get_schedule_queryset_for_account(account):
    """
    Return only bookings the authenticated user is permitted to see.
    Admins can monitor all bookings.
    """

    if account.role == "client":
        family = FamilyCareProfile.objects.filter(
            account=account
        ).first()

        if family is None:
            raise ValidationError(
                "Complete your family care profile first."
            )

        queryset = CareSchedule.objects.filter(
            family_profile=family
        )

    elif account.role == "caregiver":
        caregiver = Caregiver.objects.filter(
            account=account
        ).first()

        if caregiver is None:
            raise ValidationError(
                "Complete your caregiver profile first."
            )

        queryset = CareSchedule.objects.filter(
            caregiver=caregiver
        )

    elif account.role == "admin":
        queryset = CareSchedule.objects.all()

    else:
        raise PermissionDenied("Unsupported account role.")

    return queryset.select_related(
        "family_profile",
        "family_profile__account",
        "caregiver",
        "caregiver__account",
        "conversation",
    )


# ---------------------------------------------------------------------
# SECURE BASE API VIEW
# ---------------------------------------------------------------------

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
            raise PermissionDenied(
                "Family access is required."
            )

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
            raise PermissionDenied(
                "Caregiver access is required."
            )

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

        schedules = get_schedule_queryset_for_account(
            account
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

        serializer = CareScheduleSerializer(
            data=request.data
        )
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
                "scheduled_start": "Start and end times are required."
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
                "scheduled_end": "End time must be later than the start time."
            })

        if not isinstance(services, list) or not services:
            raise ValidationError({
                "services": "Select at least one care service."
            })

        try:
            requested_service_ids = {
                int(service_id)
                for service_id in services
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
                        "The caregiver already has a booking during "
                        "this period. Choose another time or caregiver."
                    )
                })

            conversation, _ = get_or_create_conversation(
                family,
                locked_caregiver,
            )

            schedule = serializer.save(
                family_profile=family,
                caregiver=locked_caregiver,
                conversation=conversation,
                status="pending",
                services=sorted(requested_service_ids),
            )

            # In-app notification for the caregiver.
            create_in_app_notification(
                recipient=locked_caregiver.account,
                notification_type="new_booking",
                title="New booking request",
                body=(
                    f"{family.account.full_name} has sent you a "
                    f"new booking request (#{schedule.pk})."
                ),
                schedule=schedule,
                conversation=conversation,
            )

            # Email notification for the caregiver.
            notify_after_commit(
                locked_caregiver.account,
                "New MzaziCare booking request",
                (
                    f"You have received a new booking request "
                    f"from {family.account.full_name}.\n\n"
                    f"Booking reference: #{schedule.pk}\n"
                    "Please sign in to MzaziCare to review and "
                    "accept or decline this request."
                ),
            )

        schedule = (
            CareSchedule.objects.select_related(
                "family_profile",
                "family_profile__account",
                "caregiver",
                "caregiver__account",
                "conversation",
            )
            .get(pk=schedule.pk)
        )

        return Response(
            CareScheduleSerializer(schedule).data,
            status=status.HTTP_201_CREATED,
        )


class CareScheduleDetailView(SecureAPIView):

    def get_schedule(self, request, pk):
        account = self.get_account(request)

        queryset = get_schedule_queryset_for_account(
            account
        )

        return get_object_or_404(
            queryset,
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

        if account.role == "admin":
            raise PermissionDenied(
                "Admins can monitor bookings but cannot change "
                "booking decisions here."
            )

        if schedule.status in (
            "completed",
            "cancelled",
            "declined",
        ):
            raise ValidationError(
                "This booking can no longer be changed."
            )

        # Caregiver status updates.
        if account.role == "caregiver":

            if set(request.data.keys()) != {"status"}:
                raise PermissionDenied(
                    "Caregivers can only update booking status."
                )

            transitions = {
                "confirmed": {
                    "in_progress",
                    "cancelled",
                },
                "in_progress": {
                    "completed",
                },
            }

            new_status = request.data.get("status")

            if new_status not in transitions.get(
                schedule.status,
                set(),
            ):
                raise ValidationError({
                    "status": (
                        f"Cannot change status from '{schedule.status}' "
                        f"to '{new_status}'. Use the booking decision "
                        "endpoint to accept or decline pending requests."
                    )
                })

            schedule.status = new_status

            schedule.save(
                update_fields=[
                    "status",
                    "updated_at",
                ]
            )

            # Notify the family when the caregiver cancels or completes
            # a booking.
            if new_status in ("cancelled", "completed"):
                notification_type = (
                    "booking_cancelled"
                    if new_status == "cancelled"
                    else "booking_updated"
                )

                notification_title = (
                    "Booking cancelled"
                    if new_status == "cancelled"
                    else "Care visit completed"
                )

                notification_body = (
                    f"Your caregiver has cancelled booking #{schedule.pk}."
                    if new_status == "cancelled"
                    else f"Your caregiver has marked booking #{schedule.pk} "
                         "as completed."
                )

                create_in_app_notification(
                    recipient=schedule.family_profile.account,
                    notification_type=notification_type,
                    title=notification_title,
                    body=notification_body,
                    schedule=schedule,
                    conversation=schedule.conversation,
                )

            return Response(
                CareScheduleSerializer(schedule).data
            )

        # Only families can edit their own pending bookings.
        if account.role != "client":
            raise PermissionDenied("Unsupported account role.")

        if schedule.status != "pending":
            raise ValidationError(
                "Only pending bookings can be edited by the family."
            )

        forbidden_fields = {
            "family_profile",
            "status",
            "conversation",
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
            "caregiver",
            schedule.caregiver,
        )

        start = serializer.validated_data.get(
            "scheduled_start",
            schedule.scheduled_start,
        )

        end = serializer.validated_data.get(
            "scheduled_end",
            schedule.scheduled_end,
        )

        services = serializer.validated_data.get(
            "services",
            schedule.services,
        )

        if end <= start:
            raise ValidationError({
                "scheduled_end": "End time must be later than the start time."
            })

        if start <= timezone.now():
            raise ValidationError({
                "scheduled_start": "Choose a future date and time."
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
                int(service_id)
                for service_id in services
            }
        except (TypeError, ValueError):
            raise ValidationError({
                "services": "Provide valid service IDs."
            })

        if not requested_service_ids:
            raise ValidationError({
                "services": "Select at least one care service."
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

        previous_caregiver = schedule.caregiver

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
                    "caregiver": "The caregiver is no longer available."
                })

            conflict = CareSchedule.objects.filter(
                caregiver=locked_caregiver,
                scheduled_start__lt=end,
                scheduled_end__gt=start,
                status__in=ACTIVE_BOOKING_STATUSES,
            ).exclude(
                pk=schedule.pk
            ).exists()

            if conflict:
                raise ValidationError({
                    "scheduled_start": (
                        "The caregiver already has a booking during "
                        "this period."
                    )
                })

            conversation, _ = get_or_create_conversation(
                schedule.family_profile,
                locked_caregiver,
            )

            schedule = serializer.save(
                caregiver=locked_caregiver,
                conversation=conversation,
                services=sorted(requested_service_ids),
            )

            # If the caregiver changed, notify the previous caregiver.
            if (
                previous_caregiver
                and previous_caregiver.pk != locked_caregiver.pk
            ):
                create_in_app_notification(
                    recipient=previous_caregiver.account,
                    notification_type="booking_cancelled",
                    title="Booking reassigned",
                    body=(
                        f"Booking #{schedule.pk} has been reassigned "
                        "to another caregiver."
                    ),
                    schedule=schedule,
                    conversation=schedule.conversation,
                )

            # Notify the currently assigned caregiver.
            create_in_app_notification(
                recipient=locked_caregiver.account,
                notification_type="booking_updated",
                title="Booking request updated",
                body=(
                    f"A family has updated booking #{schedule.pk}. "
                    "Please review the updated request."
                ),
                schedule=schedule,
                conversation=conversation,
            )

            notify_after_commit(
                locked_caregiver.account,
                "MzaziCare booking request updated",
                (
                    f"A family has updated booking #{schedule.pk}.\n\n"
                    "Please sign in to MzaziCare to review the request."
                ),
            )

        schedule.refresh_from_db()

        return Response(
            CareScheduleSerializer(schedule).data
        )


class CancelCareScheduleView(SecureAPIView):

    def post(self, request, pk):
        family = self.get_family(request)

        with transaction.atomic():

            schedule = get_object_or_404(
                CareSchedule.objects.select_for_update().select_related(
                    "family_profile",
                    "family_profile__account",
                    "caregiver",
                    "caregiver__account",
                    "conversation",
                ),
                pk=pk,
                family_profile=family,
            )

            if schedule.status in (
                "completed",
                "cancelled",
                "declined",
            ):
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

            if schedule.caregiver:

                # In-app notification for the caregiver.
                create_in_app_notification(
                    recipient=schedule.caregiver.account,
                    notification_type="booking_cancelled",
                    title="Booking cancelled",
                    body=(
                        f"The family has cancelled booking "
                        f"#{schedule.pk}."
                    ),
                    schedule=schedule,
                    conversation=schedule.conversation,
                )

                # Email notification for the caregiver.
                notify_after_commit(
                    schedule.caregiver.account,
                    "MzaziCare booking cancelled",
                    (
                        f"Booking #{schedule.pk} has been cancelled "
                        "by the family.\n\n"
                        "Sign in to MzaziCare to view the update."
                    ),
                )

        return Response(
            CareScheduleSerializer(schedule).data
        )


# ---------------------------------------------------------------------
# CAREGIVER ACCEPT / DECLINE BOOKING
# ---------------------------------------------------------------------

class CaregiverBookingDecisionView(SecureAPIView):
    """
    Only the caregiver assigned to a pending booking
    can accept or decline that booking.
    """

    def post(self, request, pk, decision):
        caregiver = self.get_caregiver(request)

        if decision not in ("accept", "decline"):
            raise ValidationError(
                "Decision must be either 'accept' or 'decline'."
            )

        with transaction.atomic():

            schedule = get_object_or_404(
                CareSchedule.objects
                .select_for_update(of=("self",))
                .select_related(
                    "family_profile",
                    "family_profile__account",
                    "caregiver",
                    "caregiver__account",
                    "conversation",
                ),
                pk=pk,
                caregiver=caregiver,
            )

            if schedule.status != "pending":
                raise ValidationError(
                    "Only pending booking requests can be accepted "
                    "or declined."
                )

            if not caregiver.is_verified:
                raise PermissionDenied(
                    "Your caregiver account must be verified."
                )

            if decision == "accept":

                conflict = CareSchedule.objects.filter(
                    caregiver=caregiver,
                    scheduled_start__lt=schedule.scheduled_end,
                    scheduled_end__gt=schedule.scheduled_start,
                    status__in=(
                        "confirmed",
                        "in_progress",
                    ),
                ).exclude(
                    pk=schedule.pk
                ).exists()

                if conflict:
                    raise ValidationError(
                        "You already have a confirmed booking "
                        "during this period."
                    )

                schedule.status = "confirmed"

                notification_type = "booking_accepted"
                notification_title = "Booking accepted"
                notification_body = (
                    f"{caregiver.account.full_name} has accepted "
                    f"your booking request (#{schedule.pk})."
                )

                email_subject = (
                    "Your MzaziCare booking is confirmed"
                )

                email_message = (
                    f"Your caregiver {caregiver.account.full_name} "
                    f"has accepted booking #{schedule.pk}.\n\n"
                    "Please sign in to MzaziCare to view your "
                    "booking and continue the conversation."
                )

            else:

                schedule.status = "declined"

                notification_type = "booking_declined"
                notification_title = "Booking declined"
                notification_body = (
                    f"{caregiver.account.full_name} has declined "
                    f"your booking request (#{schedule.pk}). "
                    "You can find another caregiver."
                )

                email_subject = (
                    "Your MzaziCare booking was declined"
                )

                email_message = (
                    f"Your caregiver {caregiver.account.full_name} "
                    f"has declined booking #{schedule.pk}.\n\n"
                    "You can return to MzaziCare to find another "
                    "verified caregiver."
                )

            schedule.save(
                update_fields=[
                    "status",
                    "updated_at",
                ]
            )

            # Notify the family about the decision.
            create_in_app_notification(
                recipient=schedule.family_profile.account,
                notification_type=notification_type,
                title=notification_title,
                body=notification_body,
                schedule=schedule,
                conversation=schedule.conversation,
            )

            notify_after_commit(
                schedule.family_profile.account,
                email_subject,
                email_message,
            )

        schedule.refresh_from_db()

        return Response(
            CareScheduleSerializer(schedule).data,
            status=status.HTTP_200_OK,
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
            raise PermissionDenied(
                "Only families and caregivers can access conversations."
            )

        conversations = conversations.select_related(
            "family_profile",
            "family_profile__account",
            "caregiver",
            "caregiver__account",
        ).prefetch_related(
            "messages"
        ).order_by(
            "-updated_at"
        )

        return Response({
            "conversations": ConversationSerializer(
                conversations,
                many=True,
            ).data
        })

    def post(self, request):
        account = self.get_account(request)

        # FAMILY: Start a conversation with a verified caregiver.
        if account.role == "client":

            family = self.get_family(request)

            caregiver_id = request.data.get("caregiver_id")

            if not caregiver_id:
                raise ValidationError({
                    "caregiver_id": "This field is required."
                })

            caregiver = get_object_or_404(
                Caregiver.objects.select_related("account"),
                caregiver_id=caregiver_id,
                is_verified=True,
            )

        # CAREGIVER: Start a conversation through an assigned booking.
        elif account.role == "caregiver":

            caregiver = self.get_caregiver(request)

            schedule_id = request.data.get("schedule_id")

            if not schedule_id:
                raise ValidationError({
                    "schedule_id": (
                        "Select one of your bookings to start "
                        "a conversation."
                    )
                })

            schedule = get_object_or_404(
                CareSchedule.objects.select_related(
                    "family_profile",
                    "family_profile__account",
                    "caregiver",
                    "caregiver__account",
                ),
                pk=schedule_id,
                caregiver=caregiver,
            )

            if schedule.status in ("cancelled", "declined"):
                raise ValidationError(
                    "You cannot start a conversation for a "
                    "cancelled or declined booking."
                )

            family = schedule.family_profile

        else:
            raise PermissionDenied(
                "Only families and caregivers can start conversations."
            )

        conversation, created = get_or_create_conversation(
            family,
            caregiver,
        )

        return Response(
            ConversationSerializer(conversation).data,
            status=(
                status.HTTP_201_CREATED
                if created
                else status.HTTP_200_OK
            ),
        )


# ---------------------------------------------------------------------
# CONVERSATION MESSAGES
# ---------------------------------------------------------------------

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
            raise PermissionDenied(
                "Only families and caregivers can access messages."
            )

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
        conversation = self.get_conversation(request, pk)
        account = self.get_account(request)

        messages = conversation.messages.select_related(
            "sender_profile"
        ).all()

        # Mark messages from the other participant as read.
        read_time = timezone.now()

        messages.filter(
            read_at__isnull=True
        ).exclude(
            sender_profile=account
        ).update(
            read_at=read_time
        )

        # Mark the related in-app message notifications as read too.
        Notification.objects.filter(
            recipient=account,
            notification_type="new_message",
            conversation=conversation,
            is_read=False,
            message__read_at__isnull=False,
        ).exclude(
            message__sender_profile=account
        ).update(
            is_read=True,
            read_at=read_time,
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

        serializer = MessageSerializer(
            data=request.data
        )
        serializer.is_valid(raise_exception=True)

        with transaction.atomic():

            message = serializer.save(
                conversation=conversation,
                sender_profile=account,
            )

            conversation.updated_at = timezone.now()

            conversation.save(
                update_fields=["updated_at"]
            )

            # Determine the other participant.
            if account.role == "client":
                recipient = conversation.caregiver.account
            else:
                recipient = conversation.family_profile.account

            # Create an in-app notification for the recipient.
            create_in_app_notification(
                recipient=recipient,
                notification_type="new_message",
                title="New message",
                body=(
                    f"{account.full_name} sent you a message: "
                    f"{message.body[:100]}"
                ),
                conversation=conversation,
                message=message,
            )

            # Send an email notification after the transaction succeeds.
            notify_after_commit(
                recipient,
                "New message on MzaziCare",
                (
                    f"You have received a new message from "
                    f"{account.full_name}.\n\n"
                    "Sign in to MzaziCare to read and reply."
                ),
            )

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

        elif account.role == "admin":

            updates = CareUpdate.objects.all()

        else:
            raise PermissionDenied(
                "Unsupported account role."
            )

        updates = updates.select_related(
            "schedule",
            "schedule__family_profile",
            "schedule__caregiver",
            "author_profile",
        ).order_by(
            "-created_at"
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

        if schedule.status not in (
            "in_progress",
            "completed",
        ):
            raise ValidationError(
                "Care updates can only be recorded for visits "
                "in progress or completed."
            )

        serializer = CareUpdateSerializer(
            data={
                **request.data,
                "schedule": schedule.pk,
            }
        )

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

        elif account.role == "admin":

            queryset = CareUpdate.objects.all()

        else:
            raise PermissionDenied(
                "Unsupported account role."
            )

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
