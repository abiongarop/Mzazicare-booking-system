
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
            "role",
            "is_verified",
            "created_at",
            "updated_at",
        ]
