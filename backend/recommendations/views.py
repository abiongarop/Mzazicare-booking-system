
from django.http import JsonResponse
from django.views.decorators.http import require_GET

from .services import rank_candidates


@require_GET
def recommendation_health(request):
    """
    Check whether the trained recommendation model can be loaded.
    """
    try:
        from .services import load_model_and_features

        model, features = load_model_and_features()

        return JsonResponse({
            "status": "success",
            "model": type(model).__name__,
            "features": features,
        })

    except Exception as exc:
        return JsonResponse({
            "status": "error",
            "message": str(exc),
        }, status=503)


@require_GET
def recommendation_status(request):
    return JsonResponse({
        "project": "MzaziCare",
        "module": "caregiver-recommendations",
        "status": "configured",
        "message": (
            "The recommendation module is configured. "
            "Client-specific matching requires candidate features."
        ),
    })


from django.http import JsonResponse
from django.views.decorators.http import require_GET

from .graph_service import get_candidate_caregivers


@require_GET
def graph_candidates(request, client_id):
    try:
        candidates = get_candidate_caregivers(client_id)

        return JsonResponse({
            "client_id": client_id,
            "candidate_count": len(candidates),
            "candidates": candidates,
        })

    except Exception:
        # Log the full exception in server logs during development.
        return JsonResponse({
            "error": "Could not retrieve graph candidates."
        }, status=503)