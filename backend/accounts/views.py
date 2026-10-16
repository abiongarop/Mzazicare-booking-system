
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from recommendations.firebase_authentication import (
    FirebaseAuthentication,
)

from .models import MzaziCareProfile
from .serializers import MzaziCareProfileSerializer


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
