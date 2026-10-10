
from rest_framework import viewsets
from .models import Client
from .serializers import ClientSerializer


class ClientViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = Client.objects.select_related(
        "location"
    ).prefetch_related("required_services")
    serializer_class = ClientSerializer