
from rest_framework import serializers

from .models import Notification


class NotificationSerializer(serializers.ModelSerializer):
    schedule_id = serializers.IntegerField(
        read_only=True,
        allow_null=True,
    )

    conversation_id = serializers.IntegerField(
        read_only=True,
        allow_null=True,
    )

    message_id = serializers.IntegerField(
        read_only=True,
        allow_null=True,
    )

    class Meta:
        model = Notification
        fields = [
            "id",
            "notification_type",
            "title",
            "body",
            "schedule_id",
            "conversation_id",
            "message_id",
            "is_read",
            "read_at",
            "created_at",
        ]
        read_only_fields = fields
