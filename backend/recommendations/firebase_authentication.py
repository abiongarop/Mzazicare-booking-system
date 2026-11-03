
import logging
import os

import firebase_admin
from firebase_admin import auth, credentials
from django.core.exceptions import ImproperlyConfigured
from rest_framework.authentication import BaseAuthentication
from rest_framework.exceptions import AuthenticationFailed

from django.conf import settings

logger = logging.getLogger(__name__)


def get_firebase_app():
    """
    Return the initialized Firebase Admin application.

    Uses Django settings to locate the service-account file.
    """

    try:
        return firebase_admin.get_app()
    except ValueError:
        pass

    service_account_path = getattr(
        settings,
        "FIREBASE_SERVICE_ACCOUNT_PATH",
        None,
    )

    if not service_account_path:
        raise ImproperlyConfigured(
            "Firebase service-account path is not configured."
        )

    service_account_path = os.path.abspath(
        service_account_path
    )

    if not os.path.isfile(service_account_path):
        raise ImproperlyConfigured(
            "Firebase service-account file was not found. "
            "Check FIREBASE_SERVICE_ACCOUNT_PATH."
        )

    try:
        credential = credentials.Certificate(
            service_account_path
        )

        return firebase_admin.initialize_app(credential)

    except Exception as exc:
        logger.exception(
            "Firebase Admin SDK initialization failed."
        )

        raise ImproperlyConfigured(
            "Firebase Admin SDK could not be initialized. "
            "Check the service-account configuration."
        ) from exc


class FirebaseAuthenticatedUser:
    """
    Lightweight authenticated user representing a verified
    Firebase identity.
    """

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

    def __str__(self):
        return self.uid


class FirebaseAuthentication(BaseAuthentication):
    """
    Authenticate Django REST Framework requests using Firebase
    ID tokens supplied in the Authorization Bearer header.
    """

    def authenticate(self, request):
        authorization = request.headers.get(
            "Authorization", ""
        ).strip()

        # Allow other authentication classes to handle requests
        # when no Authorization header is supplied.
        if not authorization:
            return None

        parts = authorization.split()

        if len(parts) != 2 or parts[0].lower() != "bearer":
            raise AuthenticationFailed(
                "Invalid Authorization header. "
                "Expected: Bearer <Firebase_ID_token>."
            )

        id_token = parts[1]

        try:
            app = get_firebase_app()

            decoded_token = auth.verify_id_token(
                id_token,
                app=app,
                check_revoked=False,
            )

            if not decoded_token.get("uid"):
                raise AuthenticationFailed(
                    "Firebase token does not contain a user UID."
                )

            user = FirebaseAuthenticatedUser(decoded_token)

            logger.debug(
                "Firebase authentication succeeded for UID %s.",
                user.uid,
            )

            return user, decoded_token

        except AuthenticationFailed:
            raise

        except Exception as exc:
            # Log the verification exception on the server.
            # Never log the actual Firebase ID token.
            logger.exception(
                "Firebase ID token verification failed."
            )

            # Keep detailed internals out of the API response.
            raise AuthenticationFailed(
                "Firebase authentication failed. "
                "Check the server logs for details."
            ) from exc

    def authenticate_header(self, request):
        return "Bearer"
