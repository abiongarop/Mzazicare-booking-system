
from django.contrib import admin
from .models import MzaziCareProfile


@admin.register(MzaziCareProfile)
class MzaziCareProfileAdmin(admin.ModelAdmin):
    list_display = (
        "full_name",
        "email",
        "role",
        "is_verified",
        "created_at",
    )

    list_filter = ("role", "is_verified")
    search_fields = ("full_name", "email", "firebase_uid")
    readonly_fields = ("firebase_uid", "created_at", "updated_at")
