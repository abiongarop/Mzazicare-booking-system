from django.urls import path

from .views import (
    CareScheduleListCreateView,
    CareScheduleDetailView,
    CancelCareScheduleView,
    CaregiverBookingDecisionView,
    ConversationListCreateView,
    ConversationMessagesView,
    CareUpdateListCreateView,
    CareUpdateDetailView,
)

urlpatterns = [
    path(
        "care-schedules/",
        CareScheduleListCreateView.as_view(),
        name="care-schedule-list",
    ),
    path(
        "care-schedules/<int:pk>/",
        CareScheduleDetailView.as_view(),
        name="care-schedule-detail",
    ),
    path(
        "care-schedules/<int:pk>/cancel/",
        CancelCareScheduleView.as_view(),
        name="care-schedule-cancel",
    ),
    path(
        "care-schedules/<int:pk>/decision/<str:decision>/",
        CaregiverBookingDecisionView.as_view(),
        name="care-schedule-decision",
    ),
    path(
        "conversations/",
        ConversationListCreateView.as_view(),
        name="conversation-list",
    ),
    path(
        "conversations/<int:pk>/messages/",
        ConversationMessagesView.as_view(),
        name="conversation-messages",
    ),
    path(
        "care-updates/",
        CareUpdateListCreateView.as_view(),
        name="care-update-list",
    ),
    path(
        "care-updates/<int:pk>/",
        CareUpdateDetailView.as_view(),
        name="care-update-detail",
    ),
]