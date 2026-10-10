
from django.db import models


class Location(models.Model):
    name = models.CharField(max_length=100, unique=True)

    def __str__(self):
        return self.name


class Skill(models.Model):
    name = models.CharField(max_length=100, unique=True)

    def __str__(self):
        return self.name


class Service(models.Model):
    name = models.CharField(max_length=100, unique=True)

    def __str__(self):
        return self.name


class Caregiver(models.Model):
    caregiver_id = models.CharField(max_length=20, unique=True)
    age = models.PositiveIntegerField()
    gender = models.CharField(max_length=30, blank=True)
    experience_years = models.PositiveIntegerField(default=0)
    rating = models.DecimalField(
        max_digits=3, decimal_places=2, default=0
    )
    location = models.ForeignKey(
        Location,
        on_delete=models.PROTECT,
        related_name="caregivers",
    )
    availability = models.CharField(max_length=100, blank=True)
    skills = models.ManyToManyField(
        Skill, blank=True, related_name="caregivers"
    )
    services = models.ManyToManyField(
        Service, blank=True, related_name="caregivers"
    )
    is_verified = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return self.caregiver_id