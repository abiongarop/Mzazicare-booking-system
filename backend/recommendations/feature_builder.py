import os


FEATURE_COLUMNS = [
    "service_match",
    "skill_match",
    "location_match",
    "availability_match",
    "experience_years",
    "experience_match",
    "rating",
    "distance_km",
]


def normalise(value):
    """Normalize text for consistent comparisons."""

    return " ".join(
        str(value or "")
        .strip()
        .lower()
        .replace("_", " ")
        .replace("-", " ")
        .split()
    )


def _get_item_value(item, possible_keys):
    """Read a value from a dictionary or model object."""

    if isinstance(item, dict):
        for key in possible_keys:
            if item.get(key) is not None:
                return item[key]

        return None

    for key in possible_keys:
        value = getattr(item, key, None)

        if value is not None:
            return value

    return None


def _item_keys(item):
    """
    Produce comparable identifiers for a service or skill.

    IDs are preferred when available. Names are retained as a
    fallback so older name-based training/input data still works.
    """

    keys = set()

    item_id = _get_item_value(
        item,
        ("id", "pk", "service_id", "skill_id"),
    )

    if item_id is not None:
        keys.add(f"id:{normalise(item_id)}")

    name = _get_item_value(
        item,
        ("name", "title", "service_name", "skill_name"),
    )

    if name is None and isinstance(item, (str, int, float)):
        name = item

    normalized_name = normalise(name)

    if normalized_name:
        keys.add(f"name:{normalized_name}")

    return keys


def _item_display_name(item):
    """Return a readable service or skill name."""

    name = _get_item_value(
        item,
        ("name", "title", "service_name", "skill_name"),
    )

    if name is None and isinstance(item, (str, int, float)):
        name = item

    if name is not None:
        return str(name).strip()

    item_id = _get_item_value(
        item,
        ("id", "pk", "service_id", "skill_id"),
    )

    return str(item_id) if item_id is not None else str(item)


def _build_lookup(items):
    """Build one lookup set for fast matching."""

    lookup = set()

    for item in items or []:
        lookup.update(_item_keys(item))

    return lookup


def overlap_score(required_items, offered_items):
    """
    Calculate the proportion of requested services or skills
    that the caregiver provides.

    Matching is based on IDs where possible, with names as fallback.
    """

    offered_lookup = _build_lookup(offered_items)

    required_keys = [
        _item_keys(item)
        for item in (required_items or [])
    ]

    # Remove duplicate requirements.
    unique_required = []

    seen = set()

    for keys in required_keys:
        identity = frozenset(keys)

        if keys and identity not in seen:
            seen.add(identity)
            unique_required.append(keys)

    if not unique_required:
        return 0.0

    matched = sum(
        1
        for required in unique_required
        if required & offered_lookup
    )

    return matched / len(unique_required)


def get_matching_items(required_items, offered_items):
    """
    Return readable names of matching services or skills.

    The offered lookup is built once, rather than repeatedly for
    each requested item.
    """

    offered_lookup = _build_lookup(offered_items)

    matches = []

    for item in required_items or []:
        if _item_keys(item) & offered_lookup:
            matches.append(_item_display_name(item))

    return sorted(set(matches), key=str.lower)


def build_candidate_features(candidate):
    """
    Build the eight model features and caregiver display details.

    The feature definitions must remain consistent with the
    definitions used when the Random Forest was trained.
    """

    required_services = candidate.get("required_services") or []
    required_skills = candidate.get("required_skills") or []

    provided_services = candidate.get("provided_services") or []
    caregiver_skills = candidate.get("skills") or []

    caregiver_locations = candidate.get("caregiver_locations") or []

    profile_location = normalise(
        candidate.get("profile_location")
    )

    caregiver_location_names = {
        normalise(location)
        for location in caregiver_locations
        if normalise(location)
    }

    location_match = bool(
        profile_location
        and profile_location in caregiver_location_names
    )

    # Temporary fallback until both parties have geographic coordinates.
    # This value must use the same scale as the training data.
    unknown_distance_km = float(
        os.getenv(
            "MZAZICARE_UNKNOWN_DISTANCE_KM",
            "10",
        )
    )

    distance_km = (
        0.0 if location_match else unknown_distance_km
    )

    experience_years = float(
        candidate.get("experience_years") or 0
    )

    rating = float(
        candidate.get("rating") or 0
    )

    min_experience = float(
        os.getenv(
            "MZAZICARE_MIN_EXPERIENCE_YEARS",
            "3",
        )
    )

    arrangement = normalise(
        candidate.get("care_arrangement")
    )

    availability = normalise(
        candidate.get("availability")
    )

    availability_match = bool(
        arrangement
        and availability
        and arrangement in availability
    )

    service_match = overlap_score(
        required_services,
        provided_services,
    )

    skill_match = overlap_score(
        required_skills,
        caregiver_skills,
    )

    features = {
        "caregiver_id": str(candidate["caregiver_id"]),
        "service_match": service_match,
        "skill_match": skill_match,
        "location_match": float(location_match),
        "availability_match": float(availability_match),
        "experience_years": experience_years,
        "experience_match": float(
            experience_years >= min_experience
        ),
        "rating": rating,
        "distance_km": distance_km,
    }

    matching_services = get_matching_items(
        required_services,
        provided_services,
    )

    matching_skills = get_matching_items(
        required_skills,
        caregiver_skills,
    )

    details = {
        "caregiver_id": str(candidate["caregiver_id"]),
        "age": candidate.get("age"),
        "gender": candidate.get("gender"),
        "experience_years": experience_years,
        "rating": rating,
        "availability": candidate.get("availability"),
        "is_verified": bool(
            candidate.get("is_verified")
        ),
        "location": caregiver_locations,
        "matching_services": matching_services,
        "matching_skills": matching_skills,
    }

    return features, details