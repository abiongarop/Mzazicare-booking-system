
from django.contrib.auth import authenticate, get_user_model
from django.db import transaction
from rest_framework import status
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken

from .auth_serializers import RegisterSerializer, LoginSerializer
from .models import AccountRole

User = get_user_model()


def get_user_role(user):
    # Django's trusted staff/superuser flags are authoritative for admin.
    if user.is_superuser or user.is_staff:
        return "admin"

    try:
        return user.account_role.role
    except AccountRole.DoesNotExist:
        return None


def build_auth_response(user):
    role = get_user_role(user)

    if role not in {"admin", "client", "caregiver"}:
        return Response(
            {"detail": "This account has no valid assigned role. Contact support."},
            status=status.HTTP_403_FORBIDDEN,
        )

    refresh = RefreshToken.for_user(user)

    return Response({
        "access": str(refresh.access_token),
        "refresh": str(refresh),
        "user": {
            "id": user.pk,
            "email": user.email,
            "full_name": user.get_full_name() or user.email,
            "role": role,
            "dashboard": {
                "admin": "/admin-dashboard",
                "client": "/family-dashboard",
                "caregiver": "/caregiver-dashboard",
            }[role],
        },
    })


class RegisterView(APIView):
    permission_classes = [AllowAny]
    authentication_classes = []

    def post(self, request):
        serializer = RegisterSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        with transaction.atomic():
            user = serializer.save()

        return build_auth_response(user)


class LoginView(APIView):
    permission_classes = [AllowAny]
    authentication_classes = []

    def post(self, request):
        serializer = LoginSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        email = serializer.validated_data["email"].strip().lower()
        password = serializer.validated_data["password"]

        # Avoid revealing whether an email exists.
        user = authenticate(
            request,
            username=email,
            password=password,
        )

        if user is None:
            return Response(
                {"detail": "Invalid email or password."},
                status=status.HTTP_401_UNAUTHORIZED,
            )

        if not user.is_active:
            return Response(
                {"detail": "This account is disabled."},
                status=status.HTTP_403_FORBIDDEN,
            )

        return build_auth_response(user)


class CurrentAccountView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = request.user
        role = get_user_role(user)

        if role is None:
            return Response(
                {"detail": "No valid role is assigned to this account."},
                status=status.HTTP_403_FORBIDDEN,
            )

        return Response({
            "id": user.pk,
            "email": user.email,
            "full_name": user.get_full_name() or user.email,
            "role": role,
        })
