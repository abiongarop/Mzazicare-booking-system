
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from recommendations.firebase_authentication import (
    FirebaseAuthentication,
)

from .models import MzaziCareProfile
from .serializers import MzaziCareProfileSerializer
from rest_framework import status

class MyProfileView(APIView):
    authentication_classes = [FirebaseAuthentication]
    permission_classes = [IsAuthenticated]

    def get_or_create_profile(self, request):
        user = request.user

        profile, created = MzaziCareProfile.objects.get_or_create(
            firebase_uid=user.uid,
            defaults={
                "email": user.email or "",
                "full_name": user.name or "",
                "role": "client",
            },
        )

        # Synchronize basic identity details from the verified
        # Firebase identity without overwriting profile details.
        fields_to_update = []

        if user.email and profile.email != user.email:
            profile.email = user.email
            fields_to_update.append("email")

        if user.name and profile.full_name != user.name:
            profile.full_name = user.name
            fields_to_update.append("full_name")

        if fields_to_update:
            profile.save(update_fields=fields_to_update)

        return profile

    def get(self, request):
        profile = self.get_or_create_profile(request)

        return Response(
            MzaziCareProfileSerializer(profile).data
        )

    def patch(self, request):
        profile = self.get_or_create_profile(request)

        serializer = MzaziCareProfileSerializer(
            profile,
            data=request.data,
            partial=True,
        )

        serializer.is_valid(raise_exception=True)
        serializer.save()

        return Response(serializer.data)

class SelectRoleView(APIView):
    authentication_classes = [FirebaseAuthentication]
    permission_classes = [IsAuthenticated]

    ALLOWED_ROLES = {"client", "caregiver"}

    def post(self, request):
        # Validate the requested role.
        role = request.data.get("role")

        if role not in self.ALLOWED_ROLES:
            return Response(
                {
                    "error": (
                        "Invalid role. Choose client or caregiver."
                    )
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Identify the signed-in Firebase user.
        firebase_uid = getattr(request.user, "uid", None)

        if not firebase_uid:
            return Response(
                {"error": "Could not identify the Firebase user."},
                status=status.HTTP_401_UNAUTHORIZED,
            )

        # The profile should normally already exist because the
        # sign-in flow calls GET /api/profile/me/.
        profile = MzaziCareProfile.objects.filter(
            firebase_uid=firebase_uid
        ).first()

        if profile is None:
            return Response(
                {
                    "error": (
                        "Profile not found. Retrieve your profile "
                        "before selecting a role."
                    )
                },
                status=status.HTTP_404_NOT_FOUND,
            )

        # Save the selected role.
        profile.role = role
        profile.save(update_fields=["role", "updated_at"])

        return Response(
            {
                "message": "Role saved successfully.",
                "profile": {
                    "firebase_uid": profile.firebase_uid,
                    "email": profile.email,
                    "full_name": profile.full_name,
                    "role": profile.role,
                },
            },
            status=status.HTTP_200_OK,
        )