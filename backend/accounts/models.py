from django.db import models

# Create your models here.

from django.db import models


class MzaziCareProfile(models.Model):
    ROLE_CHOICES = [
        ("client", "Family / Client"),
        ("caregiver", "Caregiver"),
        ("admin", "Administrator"),
    ]

    # UID comes from the verified Firebase token.
    firebase_uid = models.CharField(
        max_length=128,
        unique=True,
    )

    email = models.EmailField(blank=True)
    full_name = models.CharField(max_length=150, blank=True)

    role = models.CharField(
        max_length=20,
        choices=ROLE_CHOICES,
        default="client",
    )

    phone = models.CharField(max_length=30, blank=True)
    location = models.CharField(max_length=150, blank=True)

    # Caregivers require approval before being treated
    # as verified caregivers by the application.
    is_verified = models.BooleanField(default=False)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.full_name or self.email} ({self.role})"
