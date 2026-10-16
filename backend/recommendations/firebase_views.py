
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from .firebase_authentication import FirebaseAuthentication


class FirebaseAuthCheckView(APIView):
    authentication_classes = [FirebaseAuthentication]
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = request.user

        return Response({
            "authenticated": True,
            "firebase_uid": user.uid,
            "email": user.email,
            "name": user.name,
            "email_verified": user.email_verified,
            "message": "Firebase authentication successful.",
        })
