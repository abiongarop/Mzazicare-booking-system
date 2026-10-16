import os

from dotenv import load_dotenv
from neo4j import GraphDatabase

load_dotenv()


def load_graph():
    uri = os.getenv("NEO4J_URI")
    username = os.getenv("NEO4J_USERNAME")
    password = os.getenv("NEO4J_PASSWORD")
    database = os.getenv("NEO4J_DATABASE", "neo4j")

    if not all([uri, username, password]):
        raise RuntimeError("Neo4j connection settings are missing.")

    driver = GraphDatabase.driver(
        uri,
        auth=(username, password),
    )

    try:
        driver.verify_connectivity()

        with driver.session(database=database) as session:
            session.run("""
                CREATE CONSTRAINT caregiver_id_unique IF NOT EXISTS
                FOR (c:Caregiver)
                REQUIRE c.caregiver_id IS UNIQUE
            """).consume()

            session.run("""
                CREATE CONSTRAINT client_id_unique IF NOT EXISTS
                FOR (c:Client)
                REQUIRE c.client_id IS UNIQUE
            """).consume()

            # Add additional graph loading queries here once
            # the Django records and relationships are verified.
    finally:
        driver.close()