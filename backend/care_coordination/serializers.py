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
    conversation_id = serializers.IntegerField(
        read_only=True,
        allow_null=True,
    )

    family_profile_id = serializers.IntegerField(
        source="family_profile.id",
        read_only=True,
    )
    family_name = serializers.CharField(
        source="family_profile.account.full_name",
        read_only=True,
        default="Family",
    )
    family_phone = serializers.CharField(
        source="family_profile.contact_phone",
        read_only=True,
        default="",
    )
    family_email = serializers.EmailField(
        source="family_profile.account.email",
        read_only=True,
        default="",
    )
    family_location = serializers.CharField(
        source="family_profile.location",
        read_only=True,
        default="",
    )
    care_recipient_age = serializers.IntegerField(
        source="family_profile.care_recipient_age",
        read_only=True,
        allow_null=True,
    )
    care_recipient_gender = serializers.CharField(
        source="family_profile.care_recipient_gender",
        read_only=True,
        default="",
    )
    care_level = serializers.CharField(
        source="family_profile.care_level",
        read_only=True,
        default="",
    )
    care_arrangement = serializers.CharField(
        source="family_profile.care_arrangement",
        read_only=True,
        default="",
    )

    class Meta:
        model = CareSchedule
        fields = [
            "id",
            "caregiver",
            "caregiver_id",
            "caregiver_rating",
            "conversation_id",
            "family_profile_id",
            "family_name",
            "family_phone",
            "family_email",
            "family_location",
            "care_recipient_age",
            "care_recipient_gender",
            "care_level",
            "care_arrangement",
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
            "conversation_id",
            "family_profile_id",
            "family_name",
            "family_phone",
            "family_email",
            "family_location",
            "care_recipient_age",
            "care_recipient_gender",
            "care_level",
            "care_arrangement",
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
            raise serializers.ValidationError({
                "scheduled_end": (
                    "End time must be later than the start time."
                )
            })

        if (
            start
            and not self.instance
            and start <= timezone.now()
        ):
            raise serializers.ValidationError({
                "scheduled_start": (
                    "Choose a future date and time."
                )
            })

        return attrs


class ConversationSerializer(serializers.ModelSerializer):
    caregiver_id = serializers.CharField(
        source="caregiver.caregiver_id",
        read_only=True,
    )
    family_profile_id = serializers.IntegerField(
        source="family_profile.id",
        read_only=True,
    )
    family_name = serializers.CharField(
        source="family_profile.account.full_name",
        read_only=True,
        default="Family",
    )
    caregiver_name = serializers.CharField(
        source="caregiver.account.full_name",
        read_only=True,
        default="Caregiver",
    )
    messages_count = serializers.IntegerField(
        source="messages.count",
        read_only=True,
    )

    class Meta:
        model = Conversation
        fields = [
            "id",
            "family_profile_id",
            "family_name",
            "caregiver",
            "caregiver_id",
            "caregiver_name",
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