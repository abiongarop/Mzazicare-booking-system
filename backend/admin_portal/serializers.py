
from rest_framework import serializers

from caregivers.models import Caregiver
from clients.models import FamilyCareProfile
from care_coordination.models import CareSchedule
from care_coordination.serializers import CareScheduleSerializer


class AdminCaregiverSerializer(serializers.ModelSerializer):
    location_name = serializers.CharField(
        source="location.name",
        read_only=True,
        default="",
    )
    skills = serializers.StringRelatedField(many=True, read_only=True)
    services = serializers.StringRelatedField(many=True, read_only=True)
    account_name = serializers.CharField(
        source="account.full_name",
        read_only=True,
        default="",
    )
    account_email = serializers.CharField(
        source="account.email",
        read_only=True,
        default="",
    )

    class Meta:
        model = Caregiver
        fields = [
            "id",
            "caregiver_id",
            "account_name",
            "account_email",
            "age",
            "gender",
            "experience_years",
            "rating",
            "location",
            "location_name",
            "availability",
            "skills",
            "services",
            "is_verified",
            "created_at",
            "updated_at",
        ]
        read_only_fields = fields


class AdminFamilySerializer(serializers.ModelSerializer):
    account_name = serializers.CharField(
        source="account.full_name",
        read_only=True,
        default="",
    )
    account_email = serializers.CharField(
        source="account.email",
        read_only=True,
        default="",
    )
    account_phone = serializers.CharField(
        source="account.phone",
        read_only=True,
        default="",
    )
    required_services = serializers.StringRelatedField(
        many=True,
        read_only=True,
    )
    required_skills = serializers.StringRelatedField(
        many=True,
        read_only=True,
    )

    class Meta:
        model = FamilyCareProfile
        fields = [
            "id",
            "account_name",
            "account_email",
            "account_phone",
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
        read_only_fields = fields



class AdminCareScheduleSerializer(CareScheduleSerializer):
    family_profile = serializers.PrimaryKeyRelatedField(
        queryset=FamilyCareProfile.objects.all()
    )
    family_name = serializers.CharField(
        source="family_profile.account.full_name",
        read_only=True,
        default="",
    )
    family_email = serializers.CharField(
        source="family_profile.account.email",
        read_only=True,
        default="",
    )

    class Meta(CareScheduleSerializer.Meta):
        fields = CareScheduleSerializer.Meta.fields + [
            "family_profile",
            "family_name",
            "family_email",
        ]
        read_only_fields = [
            *CareScheduleSerializer.Meta.read_only_fields,
            
        ]
