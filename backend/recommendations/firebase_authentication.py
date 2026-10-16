
import os

import firebase_admin
from firebase_admin import auth, credentials
from django.core.exceptions import ImproperlyConfigured
from rest_framework.authentication import BaseAuthentication
from rest_framework.exceptions import AuthenticationFailed


def get_firebase_app():
    try:
        return firebase_admin.get_app()
    except ValueError:
        pass

    service_account_path = os.environ.get(
        "FIREBASE_SERVICE_ACCOUNT_PATH"
    )

    if not service_account_path:
        raise ImproperlyConfigured(
            "FIREBASE_SERVICE_ACCOUNT_PATH is not configured."
        )

    if not os.path.isfile(service_account_path):
        raise ImproperlyConfigured(
            "Firebase service account file was not found."
        )

    credential = credentials.Certificate(service_account_path)

    return firebase_admin.initialize_app(credential)


class FirebaseAuthenticatedUser:
    def __init__(self, decoded_token):
        self.uid = decoded_token["uid"]
        self.email = decoded_token.get("email")
        self.name = decoded_token.get("name")
        self.email_verified = decoded_token.get(
            "email_verified", False
        )

    @property
    def is_authenticated(self):
        return True

    @property
    def is_anonymous(self):
        return False


class FirebaseAuthentication(BaseAuthentication):
    def authenticate(self, request):
        header = request.headers.get("Authorization", "")

        if not header:
            return None

        parts = header.split()

        if len(parts) != 2 or parts[0].lower() != "bearer":
            raise AuthenticationFailed(
                "Invalid Authorization header."
            )

        id_token = parts[1]

        try:
            decoded_token = auth.verify_id_token(
                id_token,
                app=get_firebase_app(),
            )
            user = FirebaseAuthenticatedUser(decoded_token)
            return user, decoded_token

        except Exception as exc:
            raise AuthenticationFailed(
                "Invalid or expired Firebase token."
            ) from exc

    def authenticate_header(self, request):
        return "Bearer"
