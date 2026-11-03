
from django.contrib.auth import get_user_model
from rest_framework import serializers

from .models import AccountRole

User = get_user_model()


class RegisterSerializer(serializers.Serializer):
    full_name = serializers.CharField(max_length=150)
    email = serializers.EmailField()
    password = serializers.CharField(
        write_only=True,
        min_length=10,
        trim_whitespace=False,
    )
    role = serializers.ChoiceField(
        choices=[
            AccountRole.Role.FAMILY,
            AccountRole.Role.CAREGIVER,
        ]
    )

    def validate_email(self, value):
        value = value.strip().lower()
        if User.objects.filter(email__iexact=value).exists():
            raise serializers.ValidationError(
                "An account with this email already exists."
            )
        return value

    def validate_password(self, value):
        from django.contrib.auth.password_validation import (
            validate_password,
        )

        validate_password(value)
        return value

    def create(self, validated_data):
        email = validated_data["email"]
        full_name = validated_data["full_name"].strip()
        password = validated_data["password"]
        role = validated_data["role"]

        # The submitted role can only be client or caregiver.
        # The serializer does not accept an admin role.
        user = User.objects.create_user(
            username=email,
            email=email,
            password=password,
            first_name=full_name,
        )

        AccountRole.objects.create(user=user, role=role)
        return user


class LoginSerializer(serializers.Serializer):
    email = serializers.EmailField()
    password = serializers.CharField(
        write_only=True,
        trim_whitespace=False,
    )
