
import os

from django.core.management.base import BaseCommand, CommandError

from caregivers.models import Caregiver
from clients.models import Client
from knowledge_graph.connection import get_neo4j_driver


class Command(BaseCommand):
    help = "Synchronize Django caregiver and client data to Neo4j"

    def handle(self, *args, **options):
        database = os.getenv("NEO4J_DATABASE", "neo4j")
        driver = get_neo4j_driver()

        try:
            driver.verify_connectivity()

            with driver.session(database=database) as session:
                self.create_constraints(session)

                caregiver_count = 0
                client_count = 0

                # Synchronize caregiver profiles and relationships.
                caregivers = (
                    Caregiver.objects
                    .select_related("location")
                    .prefetch_related("skills", "services")
                )

                for caregiver in caregivers.iterator():
                    record = {
                        "caregiver_id": caregiver.caregiver_id,
                        "age": caregiver.age,
                        "gender": caregiver.gender,
                        "experience_years": caregiver.experience_years,
                        "rating": float(caregiver.rating),
                        "availability": caregiver.availability,
                        "is_verified": caregiver.is_verified,
                        "location": caregiver.location.name,
                        "skills": [
                            item.name for item in caregiver.skills.all()
                        ],
                        "services": [
                            item.name for item in caregiver.services.all()
                        ],
                    }

                    session.execute_write(
                        self.write_caregiver, record
                    )
                    caregiver_count += 1

                # Synchronize client profiles and relationships.
                clients = (
                    Client.objects
                    .select_related("location")
                    .prefetch_related("required_services")
                )

                for client in clients.iterator():
                    record = {
                        "client_id": client.client_id,
                        "age": client.age,
                        "gender": client.gender,
                        "care_level": client.care_level,
                        "location": client.location.name,
                        "services": [
                            item.name
                            for item in client.required_services.all()
                        ],
                    }

                    session.execute_write(
                        self.write_client, record
                    )
                    client_count += 1

            self.stdout.write(self.style.SUCCESS(
                f"Neo4j sync complete: {caregiver_count} caregivers "
                f"and {client_count} clients processed."
            ))

        except Exception as exc:
            raise CommandError(
                f"Neo4j synchronization failed: {exc}"
            ) from exc
        finally:
            driver.close()

    @staticmethod
    def create_constraints(tx):
        tx.run("""
            CREATE CONSTRAINT caregiver_id_unique IF NOT EXISTS
            FOR (c:Caregiver)
            REQUIRE c.caregiver_id IS UNIQUE
        """).consume()

        tx.run("""
            CREATE CONSTRAINT client_id_unique IF NOT EXISTS
            FOR (c:Client)
            REQUIRE c.client_id IS UNIQUE
        """).consume()

        tx.run("""
            CREATE CONSTRAINT skill_name_unique IF NOT EXISTS
            FOR (s:Skill)
            REQUIRE s.name IS UNIQUE
        """).consume()

        tx.run("""
            CREATE CONSTRAINT service_name_unique IF NOT EXISTS
            FOR (s:Service)
            REQUIRE s.name IS UNIQUE
        """).consume()

        tx.run("""
            CREATE CONSTRAINT location_name_unique IF NOT EXISTS
            FOR (l:Location)
            REQUIRE l.name IS UNIQUE
        """).consume()

    @staticmethod
    def write_caregiver(tx, record):
        tx.run("""
            MERGE (c:Caregiver {caregiver_id: $caregiver_id})
            SET c.age = $age,
                c.gender = $gender,
                c.experience_years = $experience_years,
                c.rating = $rating,
                c.availability = $availability,
                c.is_verified = $is_verified

            MERGE (l:Location {name: $location})
            MERGE (c)-[:LOCATED_IN]->(l)

            WITH c
            UNWIND $skills AS skill_name
            MERGE (s:Skill {name: skill_name})
            MERGE (c)-[:HAS_SKILL]->(s)
        """, {
            **record,
            "skills": record["skills"] or [None],
        }).consume()

        # Load services separately to handle empty lists cleanly.
        tx.run("""
            MATCH (c:Caregiver {caregiver_id: $caregiver_id})
            OPTIONAL MATCH (c)-[old:PROVIDES]->(:Service)
            DELETE old
        """, caregiver_id=record["caregiver_id"]).consume()

        tx.run("""
            MATCH (c:Caregiver {caregiver_id: $caregiver_id})
            UNWIND $services AS service_name
            WITH c, service_name
            WHERE service_name IS NOT NULL
            MERGE (s:Service {name: service_name})
            MERGE (c)-[:PROVIDES]->(s)
        """, {
            "caregiver_id": record["caregiver_id"],
            "services": record["services"] or [None],
        }).consume()

        # Replace the skill relationships with the current source data.
        tx.run("""
            MATCH (c:Caregiver {caregiver_id: $caregiver_id})
            OPTIONAL MATCH (c)-[old:HAS_SKILL]->(:Skill)
            DELETE old
        """, caregiver_id=record["caregiver_id"]).consume()

        tx.run("""
            MATCH (c:Caregiver {caregiver_id: $caregiver_id})
            UNWIND $skills AS skill_name
            WITH c, skill_name
            WHERE skill_name IS NOT NULL
            MERGE (s:Skill {name: skill_name})
            MERGE (c)-[:HAS_SKILL]->(s)
        """, {
            "caregiver_id": record["caregiver_id"],
            "skills": record["skills"] or [None],
        }).consume()

    @staticmethod
    def write_client(tx, record):
        tx.run("""
            MERGE (c:Client {client_id: $client_id})
            SET c.age = $age,
                c.gender = $gender,
                c.care_level = $care_level

            MERGE (l:Location {name: $location})
            MERGE (c)-[:LOCATED_IN]->(l)
        """, record).consume()

        tx.run("""
            MATCH (c:Client {client_id: $client_id})
            OPTIONAL MATCH (c)-[old:REQUIRES]->(:Service)
            DELETE old
        """, client_id=record["client_id"]).consume()

        tx.run("""
            MATCH (c:Client {client_id: $client_id})
            UNWIND $services AS service_name
            WITH c, service_name
            WHERE service_name IS NOT NULL
            MERGE (s:Service {name: service_name})
            MERGE (c)-[:REQUIRES]->(s)
        """, {
            "client_id": record["client_id"],
            "services": record["services"] or [None],
        }).consume()