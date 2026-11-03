
from rest_framework.permissions import BasePermission


def get_role(user):
    """Resolve a user's role from trusted server-side data."""
    if not user or not getattr(user, "is_authenticated", False):
        return None

    if getattr(user, "is_superuser", False) or getattr(user, "is_staff", False):
        return "admin"

    try:
        role = user.account_role.role
        if role in ("client", "caregiver", "admin"):
            return role
    except Exception:
        pass

    try:
        from accounts.models import MzaziCareProfile

        uid = getattr(user, "uid", None)
        if uid:
            profile = MzaziCareProfile.objects.filter(
                firebase_uid=uid
            ).only("role").first()

            if profile and profile.role in ("client", "caregiver", "admin"):
                return profile.role
    except Exception:
        pass

    return None


class IsFamilyMember(BasePermission):
    message = "Only family members can access this resource."

    def has_permission(self, request, view):
        return (
            request.user.is_authenticated
            and get_role(request.user) == "client"
        )


class IsCaregiver(BasePermission):
    message = "Only caregivers can access this resource."

    def has_permission(self, request, view):
        return (
            request.user.is_authenticated
            and get_role(request.user) == "caregiver"
        )


class IsAdministrator(BasePermission):
    message = "Administrator access is required."

    def has_permission(self, request, view):
        return (
            request.user.is_authenticated
            and get_role(request.user) == "admin"
        )


class IsFamilyOrCaregiver(BasePermission):
    message = "Only family members and caregivers can access this resource."

    def has_permission(self, request, view):
        return (
            request.user.is_authenticated
            and get_role(request.user) in ("client", "caregiver")
        )


class IsOwnerOrAdministrator(BasePermission):
    """
    Object-level permission for objects that expose an `account` or `user`
    relationship. Adapt this to the actual ownership fields of each model.
    """

    def has_object_permission(self, request, view, obj):
        if get_role(request.user) == "admin":
            return True

        owner = getattr(obj, "user", None)
        if owner is not None and owner == request.user:
            return True

        account = getattr(obj, "account", None)
        if account is not None:
            firebase_uid = getattr(request.user, "uid", None)
            if firebase_uid and getattr(
                account, "firebase_uid", None
            ) == firebase_uid:
                return True

            # Django-backed profile ownership.
            if getattr(account, "user_id", None) == request.user.pk:
                return True

        return False
