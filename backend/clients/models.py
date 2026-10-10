
from django.db import models
from caregivers.models import Location, Service


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
        Service, blank=True, related_name="clients"
    )
    care_level = models.CharField(max_length=50, blank=True)
    notes = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return self.client_id