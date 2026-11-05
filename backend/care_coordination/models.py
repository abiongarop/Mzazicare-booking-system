from django.conf import settings
from django.db import models


class CareSchedule(models.Model):
    STATUS_CHOICES = [
        ("pending", "Pending"),
        ("confirmed", "Confirmed"),
        ("declined", "Declined"),
        ("in_progress", "In progress"),
        ("completed", "Completed"),
        ("cancelled", "Cancelled"),
    ]

    ARRANGEMENT_CHOICES = [
        ("one_time", "One time"),
        ("recurring", "Recurring"),
    ]

    family_profile = models.ForeignKey(
        "clients.FamilyCareProfile",
        on_delete=models.CASCADE,
        related_name="care_schedules",
    )
    caregiver = models.ForeignKey(
        "caregivers.Caregiver",
        on_delete=models.PROTECT,
        related_name="care_schedules",
        null=True,
        blank=True,
    )
    conversation = models.ForeignKey(
        "Conversation",
        on_delete=models.SET_NULL,
        related_name="care_schedules",
        null=True,
        blank=True,
    )
    scheduled_start = models.DateTimeField()
    scheduled_end = models.DateTimeField()
    arrangement = models.CharField(
        max_length=20,
        choices=ARRANGEMENT_CHOICES,
        default="one_time",
    )
    status = models.CharField(
        max_length=20,
        choices=STATUS_CHOICES,
        default="pending",
    )
    services = models.JSONField(default=list, blank=True)
    family_notes = models.TextField(blank=True)
    cancellation_reason = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["scheduled_start"]
        indexes = [
            models.Index(fields=["family_profile", "scheduled_start"]),
            models.Index(fields=["caregiver", "scheduled_start"]),
            models.Index(fields=["status"]),
        ]

    def __str__(self):
        return f"Schedule #{self.pk} - {self.status}"


class Conversation(models.Model):
    family_profile = models.ForeignKey(
        "clients.FamilyCareProfile",
        on_delete=models.CASCADE,
        related_name="conversations",
    )
    caregiver = models.ForeignKey(
        "caregivers.Caregiver",
        on_delete=models.CASCADE,
        related_name="conversations",
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=["family_profile", "caregiver"],
                name="unique_family_caregiver_conversation",
            )
        ]
        ordering = ["-updated_at"]

    def __str__(self):
        return f"Conversation #{self.pk}"


class Message(models.Model):
    conversation = models.ForeignKey(
        Conversation,
        on_delete=models.CASCADE,
        related_name="messages",
    )
    sender_profile = models.ForeignKey(
        "accounts.MzaziCareProfile",
        on_delete=models.PROTECT,
        related_name="sent_care_messages",
    )
    body = models.TextField(max_length=5000)
    created_at = models.DateTimeField(auto_now_add=True)
    read_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ["created_at"]

    def __str__(self):
        return f"Message #{self.pk}"


class CareUpdate(models.Model):
    UPDATE_TYPES = [
        ("visit_summary", "Visit summary"),
        ("activity", "Activity completed"),
        ("observation", "Observation"),
        ("medication", "Medication note"),
        ("follow_up", "Follow-up required"),
        ("incident", "Incident"),
    ]

    schedule = models.ForeignKey(
        CareSchedule,
        on_delete=models.CASCADE,
        related_name="care_updates",
    )
    author_profile = models.ForeignKey(
        "accounts.MzaziCareProfile",
        on_delete=models.PROTECT,
        related_name="authored_care_updates",
    )
    update_type = models.CharField(
        max_length=30,
        choices=UPDATE_TYPES,
        default="visit_summary",
    )
    title = models.CharField(max_length=200)
    body = models.TextField(max_length=5000)
    activities = models.JSONField(default=list, blank=True)
    follow_up_required = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.title} - Schedule #{self.schedule_id}"