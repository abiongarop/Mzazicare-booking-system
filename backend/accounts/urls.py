
from django.urls import path

from .views import MyProfileView, SelectRoleView

urlpatterns = [
    path("me/", MyProfileView.as_view(), name="my-profile"),
    path(
        "select-role/",
        SelectRoleView.as_view(),
        name="select-role",
    ),
]
