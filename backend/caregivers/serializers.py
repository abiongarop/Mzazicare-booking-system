
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
            "id", "caregiver_id", "age", "gender",
            "experience_years", "rating", "location",
            "availability", "skills", "services",
            "is_verified", "created_at", "updated_at",
        ]
        read_only_fields = ["id", "created_at", "updated_at"]