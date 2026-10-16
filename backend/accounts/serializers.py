
from rest_framework import serializers
from .models import MzaziCareProfile


class MzaziCareProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model = MzaziCareProfile

        fields = [
            "firebase_uid",
            "email",
            "full_name",
            "role",
            "phone",
            "location",
            "is_verified",
            "created_at",
            "updated_at",
        ]

        read_only_fields = [
            "firebase_uid",
            "email",
            "full_name",
            "is_verified",
            "created_at",
            "updated_at",
        ]

    def validate_role(self, value):
        if value not in ("client", "caregiver"):
            raise serializers.ValidationError(
                "Public profiles can only use the client "
                "or caregiver role."
            )

        return value
