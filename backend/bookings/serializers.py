
from rest_framework import serializers

from .models import Booking


class BookingSerializer(serializers.ModelSerializer):
    class Meta:
        model = Booking
        fields = [
            "id",
            "client",
            "caregiver",
            "scheduled_start",
            "scheduled_end",
            "status",
            "care_notes",
            "created_at",
        ]
        read_only_fields = ["id", "created_at"]

    def validate(self, attrs):
        start = attrs.get(
            "scheduled_start",
            getattr(self.instance, "scheduled_start", None),
        )
        end = attrs.get(
            "scheduled_end",
            getattr(self.instance, "scheduled_end", None),
        )
        caregiver = attrs.get(
            "caregiver",
            getattr(self.instance, "caregiver", None),
        )

        if start and end and end <= start:
            raise serializers.ValidationError({
                "scheduled_end": (
                    "The end time must be after the start time."
                )
            })

        if start and caregiver:
            conflicts = Booking.objects.filter(
                caregiver=caregiver,
                scheduled_start__lt=end,
                scheduled_end__gt=start,
                status__in=["pending", "confirmed"],
            )

            if self.instance:
                conflicts = conflicts.exclude(pk=self.instance.pk)

            if conflicts.exists():
                raise serializers.ValidationError({
                    "scheduled_start": (
                        "This caregiver already has an overlapping "
                        "pending or confirmed booking."
                    )
                })

        return attrs