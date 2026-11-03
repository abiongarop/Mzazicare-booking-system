
import logging

from django.http import JsonResponse
from django.views.decorators.http import require_GET

from rest_framework import status
from rest_framework.decorators import (
    api_view,
    authentication_classes,
    permission_classes,
)
from rest_framework.exceptions import PermissionDenied
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from accounts.models import MzaziCareProfile
from accounts.permissions import IsFamilyMember
from clients.models import FamilyCareProfile
from caregivers.models import Caregiver

from .feature_builder import build_candidate_features
from .firebase_authentication import FirebaseAuthentication
from .graph_service import (
    get_family_profile_candidates,
    sync_family_profile_to_neo4j,
)
from .services import rank_candidates


logger = logging.getLogger(__name__)

def build_plain_language_explanation(explanation, caregiver_details):
    positive = []
    negative = []

    descriptions = {
        "service_match": "the services this caregiver offers",
        "skill_match": "the caregiver's skills",
        "availability_match": "the caregiver's availability",
        "location_match": "how well the caregiver's location suits your area",
        "distance_km": "the distance between the caregiver and your home",
        "experience_years": "the caregiver's years of experience",
        "experience_match": "whether the caregiver meets the required experience level",
        "rating": "the caregiver's rating",
    }

    for item in explanation or []:
        feature = item.get("feature")
        impact = item.get("impact")
        description = descriptions.get(feature)

        if not description:
            continue

        if impact == "increased":
            positive.append(description)
        elif impact == "decreased":
            negative.append(description)

    sentences = []

    if positive:
        sentences.append(
            "This caregiver matched your needs in areas such as "
            + ", ".join(positive) + "."
        )

    if negative:
        sentences.append(
            "Some areas that did not strengthen the match were "
            + ", ".join(negative) + "."
        )

    if not sentences:
        sentences.append(
            "The system identified this caregiver as a potential match "
            "based on the available information."
        )

    sentences.append(
        "Please review the caregiver's profile and confirm their services "
        "and availability before booking."
    )

    return " ".join(sentences)


@require_GET
def recommendation_health(request):
    """Check whether the trained recommendation model can be loaded."""
    try:
        from .services import load_model_and_features

        model, features = load_model_and_features()

        return JsonResponse({
            "status": "success",
            "model": type(model).__name__,
            "features": features,
        })

    except Exception:
        logger.exception("Recommendation health check failed.")

        return JsonResponse(
            {
                "status": "error",
                "message": "The recommendation model is unavailable.",
            },
            status=status.HTTP_503_SERVICE_UNAVAILABLE,
        )


@require_GET
def recommendation_status(request):
    """Return basic recommendation module status."""
    return JsonResponse({
        "project": "MzaziCare",
        "module": "caregiver-recommendations",
        "status": "configured",
        "message": (
            "Family matching uses Neo4j candidates, "
            "Random Forest scoring, and SHAP explanations."
        ),
    })


@require_GET
def graph_candidates(request, client_id):
    """Legacy endpoint retained for compatibility."""
    return JsonResponse(
        {
            "error": (
                "This legacy endpoint is not connected yet. "
                "Use /api/recommendations/family/ for family matching."
            ),
            "client_id": client_id,
        },
        status=501,
    )


@api_view(["GET"])
@authentication_classes([FirebaseAuthentication])
@permission_classes([IsAuthenticated, IsFamilyMember])
def family_recommendations(request):
    """
    Generate caregiver recommendations for the authenticated family.

    Django FamilyCareProfile is the source of truth.
    Its latest requirements are synchronized to Neo4j before
    candidate retrieval and Random Forest ranking.
    """

    # ---------------------------------------------------------
    # 1. Identify authenticated Firebase user
    # ---------------------------------------------------------
    firebase_uid = getattr(request.user, "uid", None)

    if not firebase_uid:
        logger.warning(
            "Recommendation request has no Firebase UID."
        )

        return Response(
            {"error": "A verified Firebase identity is required."},
            status=status.HTTP_401_UNAUTHORIZED,
        )

    # ---------------------------------------------------------
    # 2. Retrieve MzaziCare account
    # ---------------------------------------------------------
    try:
        account = MzaziCareProfile.objects.filter(
            firebase_uid=firebase_uid
        ).first()

    except Exception:
        logger.exception(
            "Failed to retrieve MzaziCare account."
        )

        return Response(
            {"error": "Could not retrieve your account profile."},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR,
        )

    if account is None:
        return Response(
            {
                "error": (
                    "Your MzaziCare account was not found. "
                    "Please complete account onboarding."
                )
            },
            status=status.HTTP_404_NOT_FOUND,
        )

    if account.role != "client":
        raise PermissionDenied(
            "Only family accounts can request recommendations."
        )

    # ---------------------------------------------------------
    # 3. Retrieve latest family care profile
    # ---------------------------------------------------------
    try:
        profile = (
            FamilyCareProfile.objects
            .prefetch_related(
                "required_services",
                "required_skills",
            )
            .filter(account=account)
            .first()
        )

    except Exception:
        logger.exception(
            "Failed to retrieve family care profile."
        )

        return Response(
            {"error": "Could not retrieve your family care profile."},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR,
        )

    if profile is None:
        return Response(
            {
                "error": (
                    "Family care profile not found. "
                    "Please complete your family care profile first."
                )
            },
            status=status.HTTP_404_NOT_FOUND,
        )

    profile_id = str(profile.pk)

    # ---------------------------------------------------------
    # 4. Synchronize latest Django profile to Neo4j
    # ---------------------------------------------------------
    try:
        sync_family_profile_to_neo4j(profile)

        logger.info(
            "Synchronized family profile %s to Neo4j.",
            profile_id,
        )

    except Exception:
        logger.exception(
            "Failed to synchronize family profile %s to Neo4j.",
            profile_id,
        )

        return Response(
            {
                "error": (
                    "Your care requirements could not be synchronized "
                    "with the matching knowledge graph. Please try again."
                )
            },
            status=status.HTTP_503_SERVICE_UNAVAILABLE,
        )

    # ---------------------------------------------------------
    # 5. Retrieve Neo4j caregiver candidates
    # ---------------------------------------------------------
    try:
        candidates = get_family_profile_candidates(profile_id)

    except Exception:
        logger.exception(
            "Failed to retrieve Neo4j candidates for profile %s.",
            profile_id,
        )

        return Response(
            {
                "error": (
                    "Could not retrieve caregiver candidates from "
                    "the knowledge graph."
                )
            },
            status=status.HTTP_503_SERVICE_UNAVAILABLE,
        )

    if not candidates:
        logger.info(
            "No candidates found for family profile %s.",
            profile_id,
        )

        return Response({
            "family_profile_id": profile_id,
            "candidate_count": 0,
            "recommendations": [],
            "message": (
                "No caregiver candidates were found. "
                "Check caregiver graph synchronization and requirements."
            ),
        })

    # ---------------------------------------------------------
    # 6. Build recommendation features
    # ---------------------------------------------------------
    feature_rows = []
    details_by_id = {}

    try:
        for candidate in candidates:
            features, details = build_candidate_features(candidate)

            caregiver_id = details.get("caregiver_id")

            if caregiver_id is None:
                logger.warning(
                    "Skipping candidate with missing caregiver_id."
                )
                continue

            caregiver_id = str(caregiver_id).strip()

            if not caregiver_id:
                continue

            if caregiver_id in details_by_id:
                logger.warning(
                    "Duplicate caregiver candidate skipped: %s",
                    caregiver_id,
                )
                continue

            details["caregiver_id"] = caregiver_id

            feature_rows.append(features)
            details_by_id[caregiver_id] = details

    except Exception:
        logger.exception(
            "Feature building failed for profile %s.",
            profile_id,
        )

        return Response(
            {
                "error": (
                    "Could not prepare caregiver matching features. "
                    "Check candidate data and feature configuration."
                )
            },
            status=status.HTTP_500_INTERNAL_SERVER_ERROR,
        )

    if not feature_rows:
        return Response({
            "family_profile_id": profile_id,
            "candidate_count": 0,
            "recommendations": [],
            "message": "No valid caregiver candidates were available.",
        })

        # ---------------------------------------------------------
    # 6. Load verified Django caregiver records
    # ---------------------------------------------------------
    try:
        caregiver_records = {
            str(caregiver.caregiver_id).strip(): caregiver
            for caregiver in Caregiver.objects.filter(
                is_verified=True
            ).only(
                "id",
                "caregiver_id",
                "is_verified",
            ).iterator()
        }

    except Exception:
        logger.exception(
            "Failed to load verified caregiver records."
        )

        return Response(
            {
                "error": (
                    "Could not retrieve verified caregiver records."
                )
            },
            status=status.HTTP_500_INTERNAL_SERVER_ERROR,
        )

    # Neo4j provides matching data, but Django controls verification.
    verified_candidates = [
        candidate
        for candidate in candidates
        if str(candidate.get("caregiver_id") or "").strip()
        in caregiver_records
    ]

    if not verified_candidates:
        return Response({
            "family_profile_id": profile_id,
            "candidate_count": 0,
            "recommendations": [],
            "message": (
                "No verified caregivers matched the knowledge graph "
                "candidates. Caregiver verification is required."
            ),
        })

    # ---------------------------------------------------------
    # 7. Build recommendation features for verified candidates
    # ---------------------------------------------------------
    feature_rows = []
    details_by_id = {}

    try:
        for candidate in verified_candidates:
            features, details = build_candidate_features(candidate)

            caregiver_id = str(
                details.get("caregiver_id") or ""
            ).strip()

            if not caregiver_id:
                logger.warning(
                    "Skipping candidate with missing caregiver_id."
                )
                continue

            if caregiver_id in details_by_id:
                logger.warning(
                    "Duplicate caregiver candidate skipped: %s",
                    caregiver_id,
                )
                continue

            details["caregiver_id"] = caregiver_id

            feature_rows.append(features)
            details_by_id[caregiver_id] = details

    except Exception:
        logger.exception(
            "Feature building failed for profile %s.",
            profile_id,
        )

        return Response(
            {
                "error": (
                    "Could not prepare caregiver matching features. "
                    "Check candidate data and feature configuration."
                )
            },
            status=status.HTTP_500_INTERNAL_SERVER_ERROR,
        )

    if not feature_rows:
        return Response({
            "family_profile_id": profile_id,
            "candidate_count": 0,
            "recommendations": [],
            "message": "No valid verified caregiver candidates were available.",
        })

    # ---------------------------------------------------------
    # 7. Rank candidates using Random Forest and SHAP service
    # ---------------------------------------------------------
    try:
        ranked = rank_candidates(feature_rows)

    except Exception:
        logger.exception(
            "Recommendation scoring failed for profile %s.",
            profile_id,
        )

        return Response(
            {
                "error": (
                    "The recommendation model could not score candidates. "
                    "Check the trained model and feature configuration."
                )
            },
            status=status.HTTP_500_INTERNAL_SERVER_ERROR,
        )

    if ranked is None:
        logger.error(
            "rank_candidates returned None for profile %s.",
            profile_id,
        )

        return Response(
            {
                "error": "The recommendation model returned no valid result."
            },
            status=status.HTTP_500_INTERNAL_SERVER_ERROR,
        )

    

    # ---------------------------------------------------------
    # 9. Combine ranking and caregiver database records
    # ---------------------------------------------------------
    recommendations = []

    try:
        for result in ranked:
            if result.get("caregiver_id") is None:
                logger.warning(
                    "Ranked result missing caregiver_id: %s",
                    result,
                )
        for position, result in enumerate(ranked, start=1):
            caregiver_id = result.get("caregiver_id")

            if caregiver_id is None:
                continue

            caregiver_id = str(caregiver_id).strip()

            details = details_by_id.get(caregiver_id)

            if details is None:
                logger.warning(
                    "Missing candidate details for %s.",
                    caregiver_id,
                )
                continue

            caregiver_record = caregiver_records.get(caregiver_id)

            if caregiver_record is None:
                continue

            recommendation = {
                **details,
                **result,
                "caregiver_id": caregiver_id,
                "caregiver_database_id": caregiver_record.pk,
                "is_verified": caregiver_record.is_verified,
                "recommendation_rank": position,
                "why_recommended": build_plain_language_explanation(
                    result.get("explanation", []),
                    details,
                ),
            }

            recommendations.append(recommendation)



    except Exception:
        logger.exception(
            "Failed to assemble recommendations for profile %s.",
            profile_id,
        )

        return Response(
            {"error": "Could not assemble caregiver recommendations."},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR,
        )

    # ---------------------------------------------------------
    # 10. Return recommendations
    # ---------------------------------------------------------
    logger.info(
        "Generated %s recommendations for profile %s "
        "from %s Neo4j candidates.",
        len(recommendations),
        profile_id,
        len(candidates),
    )

    response_data = {
        "family_profile_id": profile_id,
        "candidate_count": len(recommendations),
        "recommendations": recommendations,
    }

    if not recommendations:
        response_data["message"] = (
            "No ranked recommendations matched verified Django "
            "caregiver records. Check caregiver IDs across Neo4j and Django."
        )

    return Response(response_data)
