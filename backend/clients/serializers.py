
from rest_framework import serializers

from caregivers.models import Service, Skill
from .models import Client, FamilyCareProfile


class ClientSerializer(serializers.ModelSerializer):
    location_name = serializers.CharField(
        source="location.name",
        read_only=True
    )

    required_services = serializers.StringRelatedField(
        many=True,
        read_only=True
    )

    class Meta:
        model = Client
        fields = [
            "id",
            "client_id",
            "age",
            "gender",
            "location",
            "location_name",
            "required_services",
            "care_level",
            "notes",
            "created_at",
            "updated_at",
        ]


class FamilyCareProfileSerializer(serializers.ModelSerializer):
    required_services = serializers.SerializerMethodField()
    required_skills = serializers.SerializerMethodField()

    class Meta:
        model = FamilyCareProfile
        fields = [
            "id",
            "contact_phone",
            "location",
            "care_recipient_age",
            "care_recipient_gender",
            "required_services",
            "required_skills",
            "care_level",
            "care_arrangement",
            "notes",
            "created_at",
            "updated_at",
        ]
        read_only_fields = ["id", "created_at", "updated_at"]

    def get_required_services(self, instance):
        return list(
            instance.required_services.values_list("name", flat=True)
        )

    def get_required_skills(self, instance):
        return list(
            instance.required_skills.values_list("name", flat=True)
        )

    def to_internal_value(self, data):
        """
        Remove the two custom input fields before normal model
        validation, then preserve them for create/update.
        """
        mutable_data = data.copy()

        services = mutable_data.pop("required_services", None)
        skills = mutable_data.pop("required_skills", None)

        validated_data = super().to_internal_value(mutable_data)

        if services is not None:
            if not isinstance(services, list):
                raise serializers.ValidationError({
                    "required_services": "Expected a list of service names."
                })
            validated_data["required_services"] = services

        if skills is not None:
            if not isinstance(skills, list):
                raise serializers.ValidationError({
                    "required_skills": "Expected a list of skill names."
                })
            validated_data["required_skills"] = skills

        return validated_data

    def create(self, validated_data):
        services = validated_data.pop("required_services", [])
        skills = validated_data.pop("required_skills", [])

        profile = FamilyCareProfile.objects.create(**validated_data)
        self._save_relationships(profile, services, skills)

        return profile

    def update(self, instance, validated_data):
        services = validated_data.pop("required_services", None)
        skills = validated_data.pop("required_skills", None)

        for attribute, value in validated_data.items():
            setattr(instance, attribute, value)

        instance.save()

        if services is not None:
            service_objects = [
                Service.objects.get_or_create(name=name.strip())[0]
                for name in services
                if isinstance(name, str) and name.strip()
            ]
            instance.required_services.set(service_objects)

        if skills is not None:
            skill_objects = [
                Skill.objects.get_or_create(name=name.strip())[0]
                for name in skills
                if isinstance(name, str) and name.strip()
            ]
            instance.required_skills.set(skill_objects)

        return instance

    @staticmethod
    def _save_relationships(profile, services, skills):
        service_objects = [
            Service.objects.get_or_create(name=name.strip())[0]
            for name in services
            if isinstance(name, str) and name.strip()
        ]

        skill_objects = [
            Skill.objects.get_or_create(name=name.strip())[0]
            for name in skills
            if isinstance(name, str) and name.strip()
        ]

        profile.required_services.set(service_objects)
        profile.required_skills.set(skill_objects)
