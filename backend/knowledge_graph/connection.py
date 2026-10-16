
import os

from dotenv import load_dotenv
from neo4j import GraphDatabase
from django.conf import settings

load_dotenv(settings.BASE_DIR / ".env")


def get_neo4j_driver():
    uri = os.getenv("NEO4J_URI")
    username = os.getenv("NEO4J_USERNAME")
    password = os.getenv("NEO4J_PASSWORD")

    if not all([uri, username, password]):
        raise RuntimeError(
            "Set NEO4J_URI, NEO4J_USERNAME and "
            "NEO4J_PASSWORD in backend/.env"
        )

    return GraphDatabase.driver(
        uri,
        auth=(username, password),
    )


def test_neo4j_connection():
    driver = get_neo4j_driver()

    try:
        driver.verify_connectivity()

        database = os.getenv("NEO4J_DATABASE", "neo4j")

        with driver.session(database=database) as session:
            result = session.run(
                "RETURN 'MzaziCare connected' AS message"
            )
            return result.single()["message"]
    finally:
        driver.close()