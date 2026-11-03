
from rest_framework import viewsets
from rest_framework.permissions import IsAuthenticated
from rest_framework.exceptions import PermissionDenied
from rest_framework.response import Response
from rest_framework.views import APIView

from accounts.models import MzaziCareProfile
from accounts.permissions import IsAdministrator, IsFamilyMember
from recommendations.firebase_authentication import FirebaseAuthentication

from .models import Client, FamilyCareProfile
from .serializers import ClientSerializer, FamilyCareProfileSerializer


class ClientViewSet(viewsets.ReadOnlyModelViewSet):
    """
    Client records are restricted to administrators.
    Family members should use their own family-care profile endpoint.
    """
    queryset = Client.objects.select_related(
        "location"
    ).prefetch_related("required_services")

    serializer_class = ClientSerializer
    authentication_classes = [FirebaseAuthentication]
    permission_classes = [IsAuthenticated, IsAdministrator]


class FamilyCareProfileView(APIView):
    authentication_classes = [FirebaseAuthentication]
    permission_classes = [IsAuthenticated, IsFamilyMember]

    def get_family_profile(self, request):
        user = request.user

        account = MzaziCareProfile.objects.filter(
            firebase_uid=user.uid
        ).first()

        if account is None:
            raise PermissionDenied(
                "Create your family account before accessing this profile."
            )

        if account.role != "client":
            raise PermissionDenied(
                "Only family members can access this profile."
            )

        profile, _ = FamilyCareProfile.objects.get_or_create(
            account=account,
        )

        return profile

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
