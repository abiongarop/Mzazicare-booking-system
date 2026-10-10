
from django.db import models
from caregivers.models import Caregiver
from clients.models import Client


class Booking(models.Model):
    STATUS_CHOICES = [
        ("pending", "Pending"),
        ("confirmed", "Confirmed"),
        ("completed", "Completed"),
        ("cancelled", "Cancelled"),
    ]

    client = models.ForeignKey(
        Client,
        on_delete=models.PROTECT,
        related_name="bookings",
    )
    caregiver = models.ForeignKey(
        Caregiver,
        on_delete=models.PROTECT,
        related_name="bookings",
    )
    scheduled_start = models.DateTimeField()
    scheduled_end = models.DateTimeField()
    status = models.CharField(
        max_length=20,
        choices=STATUS_CHOICES,
        default="pending",
    )
    care_notes = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Booking {self.pk}: {self.client} - {self.caregiver}"

    class Meta:
        ordering = ["scheduled_start"]