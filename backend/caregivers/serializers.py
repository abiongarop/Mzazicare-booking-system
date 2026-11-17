
from rest_framework import serializers

from .models import Caregiver, Location, Skill, Service


class LocationSerializer(serializers.ModelSerializer):
    class Meta:
        model = Location
        fields = ["id", "name"]


class SkillSerializer(serializers.ModelSerializer):
    class Meta:
        model = Skill
        fields = ["id", "name"]


class ServiceSerializer(serializers.ModelSerializer):
    class Meta:
        model = Service
        fields = ["id", "name"]


class CaregiverSerializer(serializers.ModelSerializer):
    location = LocationSerializer(read_only=True)
    skills = SkillSerializer(many=True, read_only=True)
    services = ServiceSerializer(many=True, read_only=True)

    class Meta:
        model = Caregiver
        fields = [
            "id",
            "caregiver_id",
            "age",
            "gender",
            "experience_years",
            "qualifications",
            "bio",
            "rating",
            "location",
            "availability",
            "preferred_working_time",
            "skills",
            "services",
            "is_verified",
            "created_at",
            "updated_at",
        ]
        read_only_fields = [
            "id",
            "caregiver_id",
            "rating",
            "is_verified",
            "created_at",
            "updated_at",
        ]

    def to_representation(self, instance):
        data = super().to_representation(instance)

        # Return simple location, skill and service names
        # in a format convenient for the Flutter application.
        data["location"] = instance.location.name

        data["skills"] = list(
            instance.skills.values_list("name", flat=True)
        )

        data["services"] = list(
            instance.services.values_list("name", flat=True)
        )

        return data
