from django.contrib import admin
from .models import Booking


@admin.register(Booking)
class BookingAdmin(admin.ModelAdmin):
    list_display = (
        "id",
        "client",
        "caregiver",
        "scheduled_start",
        "scheduled_end",
        "status",
    )
    list_filter = ("status",)
    search_fields = (
        "client__client_id",
        "caregiver__caregiver_id",
    )