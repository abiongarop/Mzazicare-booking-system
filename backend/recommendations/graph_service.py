
import os

from knowledge_graph.connection import get_neo4j_driver


def sync_family_profile_to_neo4j(profile):
    """
    Synchronise a saved Django FamilyCareProfile to Neo4j.

    Django remains the source of truth. Existing relationships are
    replaced so removed services and skills do not remain in Neo4j.
    """
    database = os.getenv("NEO4J_DATABASE", "neo4j")
    driver = get_neo4j_driver()

    record = {
        "profile_id": str(profile.pk),
        "care_recipient_age": profile.care_recipient_age,
        "care_recipient_gender": profile.care_recipient_gender or "",
        "care_level": profile.care_level or "",
        "care_arrangement": profile.care_arrangement or "",
        "location": (profile.location or "").strip(),
        "services": list(
            profile.required_services.values_list("name", flat=True)
        ),
        "skills": list(
            profile.required_skills.values_list("name", flat=True)
        ),
    }

    try:
        driver.verify_connectivity()

        with driver.session(database=database) as session:
            session.execute_write(_write_family_profile, record)
    finally:
        driver.close()


def _write_family_profile(tx, record):
    tx.run(
        """
        MERGE (p:FamilyCareProfile {profile_id: $profile_id})
        SET p.care_recipient_age = $care_recipient_age,
            p.care_recipient_gender = $care_recipient_gender,
            p.care_level = $care_level,
            p.care_arrangement = $care_arrangement,
            p.location = $location
        """,
        record,
    ).consume()

    # Replace the location relationship.
    tx.run(
        """
        MATCH (p:FamilyCareProfile {profile_id: $profile_id})
        OPTIONAL MATCH (p)-[old:LOCATED_IN]->(:Location)
        DELETE old
        """,
        record,
    ).consume()

    if record["location"]:
        tx.run(
            """
            MATCH (p:FamilyCareProfile {profile_id: $profile_id})
            MERGE (l:Location {name: $location})
            MERGE (p)-[:LOCATED_IN]->(l)
            """,
            record,
        ).consume()

    # Replace required service relationships.
    tx.run(
        """
        MATCH (p:FamilyCareProfile {profile_id: $profile_id})
        OPTIONAL MATCH (p)-[old:REQUIRES]->(:Service)
        DELETE old
        """,
        record,
    ).consume()

    if record["services"]:
        tx.run(
            """
            MATCH (p:FamilyCareProfile {profile_id: $profile_id})
            UNWIND $services AS service_name
            MERGE (s:Service {name: service_name})
            MERGE (p)-[:REQUIRES]->(s)
            """,
            record,
        ).consume()

    # Replace required skill relationships.
    tx.run(
        """
        MATCH (p:FamilyCareProfile {profile_id: $profile_id})
        OPTIONAL MATCH (p)-[old:REQUIRES_SKILL]->(:Skill)
        DELETE old
        """,
        record,
    ).consume()

    if record["skills"]:
        tx.run(
            """
            MATCH (p:FamilyCareProfile {profile_id: $profile_id})
            UNWIND $skills AS skill_name
            MERGE (s:Skill {name: skill_name})
            MERGE (p)-[:REQUIRES_SKILL]->(s)
            """,
            record,
        ).consume()


def get_family_profile_candidates(profile_id):
    """
    Retrieve caregiver candidates and family requirements from Neo4j.

    The returned dictionaries use the field names expected by
    recommendations.feature_builder.build_candidate_features().
    Django is still responsible for verifying caregiver records
    before they are returned to the family.
    """
    database = os.getenv("NEO4J_DATABASE", "neo4j")
    driver = get_neo4j_driver()

    query = """
    MATCH (p:FamilyCareProfile {profile_id: $profile_id})

    WITH
        p,
        [(p)-[:REQUIRES]->(s:Service) | s.name]
            AS required_services,
        [(p)-[:REQUIRES_SKILL]->(sk:Skill) | sk.name]
            AS required_skills

    OPTIONAL MATCH (p)-[:LOCATED_IN]->(pl:Location)

    WITH
        p,
        required_services,
        required_skills,
        coalesce(pl.name, p.location, '') AS profile_location

    MATCH (c:Caregiver)

    RETURN
        c.caregiver_id AS caregiver_id,
        c.age AS age,
        c.gender AS gender,
        c.experience_years AS experience_years,
        c.rating AS rating,
        c.availability AS availability,
        c.is_verified AS is_verified,

        required_services AS required_services,
        required_skills AS required_skills,

        [(c)-[:PROVIDES]->(s:Service) | s.name]
            AS provided_services,

        [(c)-[:HAS_SKILL]->(sk:Skill) | sk.name]
            AS skills,

        [(c)-[:LOCATED_IN]->(loc:Location) | loc.name]
            AS caregiver_locations,

        profile_location AS profile_location,
        p.care_arrangement AS care_arrangement
    ORDER BY caregiver_id
    """

    try:
        driver.verify_connectivity()

        with driver.session(database=database) as session:
            result = session.run(
                query,
                profile_id=str(profile_id),
            )

            candidates = []

            for record in result:
                caregiver_id = record.get("caregiver_id")

                if not caregiver_id:
                    continue

                candidates.append({
                    "caregiver_id": str(caregiver_id),
                    "age": record.get("age"),
                    "gender": record.get("gender"),
                    "experience_years": record.get("experience_years") or 0,
                    "rating": record.get("rating") or 0,
                    "availability": record.get("availability") or "",
                    "is_verified": bool(record.get("is_verified")),

                    "required_services": record.get("required_services") or [],
                    "required_skills": record.get("required_skills") or [],
                    "provided_services": record.get("provided_services") or [],
                    "skills": record.get("skills") or [],

                    "caregiver_locations": (
                        record.get("caregiver_locations") or []
                    ),
                    "profile_location": (
                        record.get("profile_location") or ""
                    ),
                    "care_arrangement": (
                        record.get("care_arrangement") or ""
                    ),
                })

            return candidates

    finally:
        driver.close()
