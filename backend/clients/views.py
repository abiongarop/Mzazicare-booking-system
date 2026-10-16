from rest_framework import viewsets
from rest_framework.permissions import IsAuthenticated
from rest_framework.exceptions import PermissionDenied
from rest_framework.response import Response
from rest_framework.views import APIView

from accounts.models import MzaziCareProfile
from recommendations.firebase_authentication import FirebaseAuthentication

from .models import Client, FamilyCareProfile
from .serializers import ClientSerializer, FamilyCareProfileSerializer


class ClientViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = Client.objects.select_related(
        "location"
    ).prefetch_related("required_services")

    serializer_class = ClientSerializer


class FamilyCareProfileView(APIView):
    authentication_classes = [FirebaseAuthentication]
    permission_classes = [IsAuthenticated]

    def get_family_profile(self, request):
        user = request.user

        account, _ = MzaziCareProfile.objects.get_or_create(
            firebase_uid=user.uid,
            defaults={
                "email": user.email or "",
                "full_name": user.name or "",
                "role": "client",
            },
        )

        # Keep basic account information up to date.
        updates = []

        if user.email and account.email != user.email:
            account.email = user.email
            updates.append("email")

        if user.name and account.full_name != user.name:
            account.full_name = user.name
            updates.append("full_name")

        if updates:
            account.save(update_fields=updates)

        if account.role != "client":
            raise PermissionDenied(
                "This endpoint is only available to family/client accounts."
            )

        family_profile, _ = FamilyCareProfile.objects.get_or_create(
            account=account,
        )

        return family_profile

    def get(self, request):
        profile = self.get_family_profile(request)
        serializer = FamilyCareProfileSerializer(profile)
        return Response(serializer.data)

    def post(self, request):
        return self.save_profile(request)

    def patch(self, request):
        return self.save_profile(request)

    def save_profile(self, request):
        profile = self.get_family_profile(request)

        serializer = FamilyCareProfileSerializer(
            profile,
            data=request.data,
            partial=True,
        )
        serializer.is_valid(raise_exception=True)
        serializer.save()

        return Response(serializer.data)