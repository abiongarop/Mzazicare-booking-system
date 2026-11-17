
from rest_framework import serializers

from .models import MzaziCareProfile


class MzaziCareProfileSerializer(serializers.ModelSerializer):

    is_verified = serializers.SerializerMethodField()

    class Meta:
        model = MzaziCareProfile

        fields = [
            "id",  # Added: required for message alignment
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
            "id",
            "firebase_uid",
            "email",
            "role",
            "is_verified",
            "created_at",
            "updated_at",
        ]

    def get_is_verified(self, obj):

        # For caregiver accounts, use the actual caregiver record.
        if obj.role == "caregiver":
            caregiver = getattr(
                obj,
                "caregiver_record",
                None
            )

            if caregiver is not None:
                return caregiver.is_verified

            return False

        # For other account types, use the account verification field.
        return getattr(obj, "is_verified", False)
