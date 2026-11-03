
from django.urls import path

from .views import (
    AdminDashboardView,
    AdminCaregiverListView,
    AdminCaregiverVerificationView,
    AdminFamilyListView,
    AdminCareScheduleListCreateView,
    AdminCareScheduleStatusView,
)

urlpatterns = [
    path("dashboard/", AdminDashboardView.as_view(), name="admin-dashboard"),
    path("caregivers/", AdminCaregiverListView.as_view(), name="admin-caregivers"),
    path(
        "caregivers/<int:pk>/verification/",
        AdminCaregiverVerificationView.as_view(),
        name="admin-caregiver-verification",
    ),
    path("families/", AdminFamilyListView.as_view(), name="admin-families"),
    path(
        "care-schedules/",
        AdminCareScheduleListCreateView.as_view(),
        name="admin-care-schedules",
    ),
    path(
        "care-schedules/<int:pk>/status/",
        AdminCareScheduleStatusView.as_view(),
        name="admin-care-schedule-status",
    ),
]
