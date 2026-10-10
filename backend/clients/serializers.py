
from rest_framework import serializers
from .models import Client


class ClientSerializer(serializers.ModelSerializer):
    location_name = serializers.CharField(
        source="location.name", read_only=True
    )
    required_services = serializers.StringRelatedField(
        many=True, read_only=True
    )

    class Meta:
        model = Client
        fields = [
            "id", "client_id", "age", "gender",
            "location", "location_name", "required_services",
            "care_level", "notes", "created_at", "updated_at",
        ]
        read_only_fields = ["id", "created_at", "updated_at"]