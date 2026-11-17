
from django.utils import timezone
from django.shortcuts import get_object_or_404

from rest_framework import status
from rest_framework.exceptions import PermissionDenied
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from accounts.models import MzaziCareProfile
from caregivers.models import Caregiver
from clients.models import FamilyCareProfile
from care_coordination.models import CareSchedule, Conversation, Message

from recommendations.firebase_authentication import FirebaseAuthentication

from .models import Notification
from .serializers import NotificationSerializer


class SecureNotificationAPIView(APIView):
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


class NotificationListView(SecureNotificationAPIView):

    def get(self, request):
        account = self.get_account(request)

        notifications = Notification.objects.filter(
            recipient=account
        )

        unread_only = request.query_params.get("unread")

        if unread_only == "true":
            notifications = notifications.filter(
                is_read=False
            )

        return Response({
            "notifications": NotificationSerializer(
                notifications[:100],
                many=True,
            ).data
        })


class NotificationSummaryView(SecureNotificationAPIView):

    def get(self, request):
        account = self.get_account(request)

        unread_notifications = Notification.objects.filter(
            recipient=account,
            is_read=False,
        )

        unread_message_count = 0
        pending_booking_count = 0

        if account.role == "client":
            family = FamilyCareProfile.objects.filter(
                account=account
            ).first()

            if family:
                unread_message_count = Message.objects.filter(
                    conversation__family_profile=family,
                    read_at__isnull=True,
                ).exclude(
                    sender_profile=account
                ).count()

                pending_booking_count = CareSchedule.objects.filter(
                    family_profile=family,
                    status="pending",
                ).count()

        elif account.role == "caregiver":
            caregiver = Caregiver.objects.filter(
                account=account
            ).first()

            if caregiver:
                unread_message_count = Message.objects.filter(
                    conversation__caregiver=caregiver,
                    read_at__isnull=True,
                ).exclude(
                    sender_profile=account
                ).count()

                pending_booking_count = CareSchedule.objects.filter(
                    caregiver=caregiver,
                    status="pending",
                ).count()

        return Response({
            "unread_notifications_count": (
                unread_notifications.count()
            ),
            "unread_message_count": unread_message_count,
            "pending_booking_count": pending_booking_count,
        })


class MarkNotificationReadView(SecureNotificationAPIView):

    def post(self, request, pk):
        account = self.get_account(request)

        notification = get_object_or_404(
            Notification,
            pk=pk,
            recipient=account,
        )

        notification.mark_as_read()

        return Response({
            "message": "Notification marked as read.",
            "notification": NotificationSerializer(
                notification
            ).data,
        })


class MarkAllNotificationsReadView(SecureNotificationAPIView):

    def post(self, request):
        account = self.get_account(request)

        unread = Notification.objects.filter(
            recipient=account,
            is_read=False,
        )

        unread.update(
            is_read=True,
            read_at=timezone.now(),
        )

        return Response({
            "message": "All notifications marked as read."
        })
