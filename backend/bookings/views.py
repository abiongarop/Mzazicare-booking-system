
from django.db.migrations import serializer
from django.test import client
from rest_framework import status, viewsets
from rest_framework.exceptions import PermissionDenied
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from accounts.models import MzaziCareProfile
from accounts.permissions import get_role
from recommendations.firebase_authentication import FirebaseAuthentication

from caregivers.models import Caregiver
from clients.models import Client

from .models import Booking
from .serializers import BookingSerializer

from django.db import transaction


class BookingViewSet(viewsets.ModelViewSet):
    serializer_class = BookingSerializer
    authentication_classes = [FirebaseAuthentication]
    permission_classes = [IsAuthenticated]

    def get_account(self):
        uid = getattr(self.request.user, "uid", None)

        if not uid:
            return None

        return MzaziCareProfile.objects.filter(
            firebase_uid=uid
        ).first()

    def get_queryset(self):
        queryset = Booking.objects.select_related(
            "client",
            "client__account",
            "caregiver",
            "caregiver__account",
        )

        role = get_role(self.request.user)

        if role == "admin":
            return queryset

        account = self.get_account()

        if account is None:
            return queryset.none()

        if role == "client":
            return queryset.filter(client__account=account)

        if role == "caregiver":
            return queryset.filter(caregiver__account=account)

        return queryset.none()

    def perform_create(self, serializer):
        role = get_role(self.request.user)

    # Only families can create bookings through this endpoint.
        if role != "client":
            raise PermissionDenied(
            "Only family members can create bookings."
        )

        account = self.get_account()

        if account is None or account.role != "client":
            raise PermissionDenied(
            "Your family account profile could not be verified."
        )

        client = serializer.validated_data["client"]
        caregiver = serializer.validated_data["caregiver"]

    # The client record must belong to this family account.
        if client.account_id != account.pk:
            raise PermissionDenied(
            "You can only book care for your own linked client record."
        )

    # Lock and re-check the caregiver at the point of booking.
        with transaction.atomic():
            locked_caregiver = (
            Caregiver.objects.select_for_update()
            .filter(pk=caregiver.pk)
            .first()
        )

        if locked_caregiver is None:
            raise PermissionDenied(
                "The selected caregiver could not be found."
            )

        if not locked_caregiver.is_verified:
            raise PermissionDenied(
                "This caregiver has not been verified by an administrator "
                "and cannot be booked."
            )

        serializer.save(
            caregiver=locked_caregiver,
            status="pending",
        )

    def update(self, request, *args, **kwargs):
        partial = kwargs.pop("partial", False)
        instance = self.get_object()
        role = get_role(request.user)

        if role == "admin":
            return super().update(
                request, partial=partial, **kwargs
            )

        if role == "client":
            # Families may cancel their own booking, but cannot change
            # its assigned client, caregiver, time, or status to confirmed.
            if request.data.get("status") != "cancelled":
                raise PermissionDenied(
                    "Family members may only cancel their own booking."
                )

            allowed_fields = {"status"}
            if set(request.data.keys()) - allowed_fields:
                raise PermissionDenied(
                    "Family members can only update booking status "
                    "to cancel a booking."
                )

            instance.status = "cancelled"
            instance.save(update_fields=["status"])
            return Response(self.get_serializer(instance).data)

        if role == "caregiver":
            # Caregivers can update the status of bookings assigned to them.
            if set(request.data.keys()) != {"status"}:
                raise PermissionDenied(
                    "Caregivers may only update the booking status."
                )

            new_status = request.data.get("status")
            if new_status not in ("confirmed", "completed", "cancelled"):
                raise PermissionDenied(
                    "That booking status change is not allowed."
                )

            if (
                new_status == "completed"
                and instance.status != "confirmed"
            ):
                raise PermissionDenied(
                    "Only confirmed bookings can be marked completed."
                )

            instance.status = new_status
            instance.save(update_fields=["status"])
            return Response(self.get_serializer(instance).data)

        raise PermissionDenied("You cannot update this booking.")

    def destroy(self, request, *args, **kwargs):
        if get_role(request.user) != "admin":
            raise PermissionDenied(
                "Only administrators can delete booking records."
            )

        return super().destroy(request, *args, **kwargs)
