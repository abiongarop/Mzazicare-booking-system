
from django.db import models
from django.utils import timezone


class Notification(models.Model):
    TYPE_CHOICES = [
        ("new_booking", "New booking request"),
        ("booking_accepted", "Booking accepted"),
        ("booking_declined", "Booking declined"),
        ("booking_cancelled", "Booking cancelled"),
        ("booking_updated", "Booking updated"),
        ("new_message", "New message"),
    ]

    recipient = models.ForeignKey(
        "accounts.MzaziCareProfile",
        on_delete=models.CASCADE,
        related_name="notifications",
    )

    notification_type = models.CharField(
        max_length=30,
        choices=TYPE_CHOICES,
    )

    title = models.CharField(max_length=200)
    body = models.TextField()

    schedule = models.ForeignKey(
        "care_coordination.CareSchedule",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="notifications",
    )

    conversation = models.ForeignKey(
        "care_coordination.Conversation",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="notifications",
    )

    message = models.ForeignKey(
        "care_coordination.Message",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="notifications",
    )

    is_read = models.BooleanField(default=False)
    read_at = models.DateTimeField(null=True, blank=True)

    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]
        indexes = [
            models.Index(
                fields=["recipient", "is_read", "-created_at"],
                name="notif_recipient_read_idx",
            ),
            models.Index(
                fields=["recipient", "notification_type"],
                name="notif_recipient_type_idx",
            ),
        ]

    def mark_as_read(self):
        if not self.is_read:
            self.is_read = True
            self.read_at = timezone.now()
            self.save(update_fields=["is_read", "read_at"])

    def __str__(self):
        return f"{self.title} - {self.recipient}"
