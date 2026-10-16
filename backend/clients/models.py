from django.db import models

from accounts.models import MzaziCareProfile
from caregivers.models import Location, Service, Skill


class Client(models.Model):
    client_id = models.CharField(max_length=20, unique=True)
    age = models.PositiveIntegerField()
    gender = models.CharField(max_length=30, blank=True)

    location = models.ForeignKey(
        Location,
        on_delete=models.PROTECT,
        related_name="clients",
    )

    required_services = models.ManyToManyField(
        Service,
        blank=True,
        related_name="clients",
    )

    care_level = models.CharField(max_length=50, blank=True)
    notes = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return self.client_id


class FamilyCareProfile(models.Model):
    CARE_ARRANGEMENT_CHOICES = [
        ("full_time", "Full-time"),
        ("part_time", "Part-time"),
        ("occasional", "Occasional"),
        ("live_in", "Live-in"),
    ]

    CARE_LEVEL_CHOICES = [
        ("basic", "Basic assistance"),
        ("moderate", "Moderate assistance"),
        ("intensive", "Intensive assistance"),
    ]

    account = models.OneToOneField(
        MzaziCareProfile,
        on_delete=models.CASCADE,
        related_name="family_care_profile",
    )

    contact_phone = models.CharField(max_length=30, blank=True)
    location = models.CharField(max_length=150, blank=True)

    care_recipient_age = models.PositiveIntegerField(
        null=True,
        blank=True,
    )

    care_recipient_gender = models.CharField(
        max_length=30,
        blank=True,
    )

    required_services = models.ManyToManyField(
        Service,
        blank=True,
        related_name="family_care_profiles",
    )

    required_skills = models.ManyToManyField(
        Skill,
        blank=True,
        related_name="family_care_profiles",
    )

    care_level = models.CharField(
        max_length=20,
        choices=CARE_LEVEL_CHOICES,
        blank=True,
    )

    care_arrangement = models.CharField(
        max_length=20,
        choices=CARE_ARRANGEMENT_CHOICES,
        blank=True,
    )

    notes = models.TextField(blank=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"Family care profile: {self.account.firebase_uid}"
