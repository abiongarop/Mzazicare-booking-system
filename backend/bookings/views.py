
from rest_framework import viewsets
from .models import Booking
from .serializers import BookingSerializer


class BookingViewSet(viewsets.ModelViewSet):
    queryset = Booking.objects.select_related(
        "client", "caregiver"
    )
    serializer_class = BookingSerializer