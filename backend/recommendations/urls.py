
from django.urls import path

from .views import (
    recommendation_health,
    recommendation_status,
    graph_candidates,
    family_recommendations,
)

urlpatterns = [
    path("health/", recommendation_health, name="recommendation-health"),
    path("status/", recommendation_status, name="recommendation-status"),
    path(
        "graph/<str:client_id>/",
        graph_candidates,
        name="graph-candidates",
    ),
    path("family/", family_recommendations, name="family-recommendations"),
]


