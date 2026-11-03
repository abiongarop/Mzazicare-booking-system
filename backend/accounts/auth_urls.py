
from django.urls import path

from .auth_views import RegisterView, LoginView, CurrentAccountView

urlpatterns = [
    path("register/", RegisterView.as_view(), name="register"),
    path("login/", LoginView.as_view(), name="login"),
    path("me/", CurrentAccountView.as_view(), name="current-account"),
]
