
from django.utils import timezone
from rest_framework import serializers

from .models import CareSchedule, Conversation, Message, CareUpdate


class CareScheduleSerializer(serializers.ModelSerializer):
    caregiver_id = serializers.CharField(
        source="caregiver.caregiver_id",
        read_only=True,
        default=None,
    )
    caregiver_rating = serializers.FloatField(
        source="caregiver.rating",
        read_only=True,
        default=None,
    )

    class Meta:
        model = CareSchedule
        fields = [
            "id",
            "caregiver",
            "caregiver_id",
            "caregiver_rating",
            "scheduled_start",
            "scheduled_end",
            "arrangement",
            "status",
            "services",
            "family_notes",
            "cancellation_reason",
            "created_at",
            "updated_at",
        ]
        read_only_fields = [
            "id",
            "status",
            "cancellation_reason",
            "created_at",
            "updated_at",
        ]

    def validate(self, attrs):
        start = attrs.get(
            "scheduled_start",
            getattr(self.instance, "scheduled_start", None),
        )
        end = attrs.get(
            "scheduled_end",
            getattr(self.instance, "scheduled_end", None),
        )

        if start and end and end <= start:
            raise serializers.ValidationError(
                {"scheduled_end": "The end must be after the start."}
            )

        if start and start <= timezone.now():
            if self.instance is None:
                raise serializers.ValidationError(
                    {"scheduled_start": "Choose a future date and time."}
                )

        return attrs


class ConversationSerializer(serializers.ModelSerializer):
    caregiver_id = serializers.CharField(
        source="caregiver.caregiver_id",
        read_only=True,
    )
    messages_count = serializers.IntegerField(
        source="messages.count",
        read_only=True,
    )

    class Meta:
        model = Conversation
        fields = [
            "id",
            "caregiver",
            "caregiver_id",
            "created_at",
            "updated_at",
            "messages_count",
        ]
        read_only_fields = fields


class MessageSerializer(serializers.ModelSerializer):
    sender_name = serializers.CharField(
        source="sender_profile.full_name",
        read_only=True,
        default="MzaziCare user",
    )

    class Meta:
        model = Message
        fields = [
            "id",
            "conversation",
            "sender_profile",
            "sender_name",
            "body",
            "created_at",
            "read_at",
        ]
        read_only_fields = [
            "id",
            "conversation",
            "sender_profile",
            "sender_name",
            "created_at",
            "read_at",
        ]

    def validate_body(self, value):
        value = value.strip()
        if not value:
            raise serializers.ValidationError(
                "A message cannot be empty."
            )
        return value


class CareUpdateSerializer(serializers.ModelSerializer):
    caregiver_id = serializers.CharField(
        source="schedule.caregiver.caregiver_id",
        read_only=True,
        default=None,
    )
    schedule_id = serializers.IntegerField(
        source="schedule.id",
        read_only=True,
    )
    author_role = serializers.CharField(
        source="author_profile.role",
        read_only=True,
    )

    class Meta:
        model = CareUpdate
        fields = [
            "id",
            "schedule",
            "schedule_id",
            "caregiver_id",
            "author_profile",
            "author_role",
            "update_type",
            "title",
            "body",
            "activities",
            "follow_up_required",
            "created_at",
        ]
        read_only_fields = [
            "id",
            "schedule",
            "schedule_id",
            "caregiver_id",
            "author_profile",
            "author_role",
            "created_at",
        ]
