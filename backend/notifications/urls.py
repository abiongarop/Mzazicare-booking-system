
from django.urls import path

from .views import (
    NotificationListView,
    NotificationSummaryView,
    MarkNotificationReadView,
    MarkAllNotificationsReadView,
)

urlpatterns = [
    path(
        "",
        NotificationListView.as_view(),
        name="notification-list",
    ),
    path(
        "summary/",
        NotificationSummaryView.as_view(),
        name="notification-summary",
    ),
    path(
        "<int:pk>/read/",
        MarkNotificationReadView.as_view(),
        name="notification-mark-read",
    ),
    path(
        "read-all/",
        MarkAllNotificationsReadView.as_view(),
        name="notification-mark-all-read",
    ),
]
