
import os

from django.conf import settings
from dotenv import load_dotenv

from knowledge_graph.connection import get_neo4j_driver

load_dotenv(settings.BASE_DIR / ".env")


CANDIDATE_QUERY = """
MATCH (cl:Client {client_id: $client_id})
      -[:REQUIRES]->(s:Service)
      <-[:PROVIDES]-(cg:Caregiver)

OPTIONAL MATCH (cg)-[:HAS_SKILL]->(skill:Skill)
OPTIONAL MATCH (cg)-[:LOCATED_IN]->(cg_location:Location)
OPTIONAL MATCH (cl)-[:LOCATED_IN]->(cl_location:Location)

RETURN
    cg.caregiver_id AS caregiver_id,
    cg.experience_years AS experience_years,
    cg.rating AS rating,
    cg.availability AS availability,
    cg_location.name AS caregiver_location,
    cl_location.name AS client_location,
    collect(DISTINCT s.name) AS matching_services,
    collect(DISTINCT skill.name) AS skills
ORDER BY size(matching_services) DESC
"""


def get_candidate_caregivers(client_id):
    driver = get_neo4j_driver()
    database = os.getenv("NEO4J_DATABASE", "neo4j")

    try:
        driver.verify_connectivity()

        with driver.session(database=database) as session:
            result = session.run(
                CANDIDATE_QUERY,
                client_id=client_id,
            )
            return [record.data() for record in result]
    finally:
        driver.close()