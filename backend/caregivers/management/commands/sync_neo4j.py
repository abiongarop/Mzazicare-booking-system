import os

from django.core.management.base import BaseCommand, CommandError

from caregivers.models import Caregiver
from clients.models import Client, FamilyCareProfile
from knowledge_graph.connection import get_neo4j_driver


class Command(BaseCommand):
    help = "Synchronize Django caregiver, client and family profiles to Neo4j"

    def handle(self, *args, **options):
        database = os.getenv("NEO4J_DATABASE", "neo4j")
        driver = get_neo4j_driver()

        try:
            driver.verify_connectivity()

            with driver.session(database=database) as session:
                self.create_constraints(session)

                caregiver_count = 0
                client_count = 0
                family_profile_count = 0

                # 1. Synchronize caregivers.
                caregivers = (
                    Caregiver.objects
                    .select_related("location")
                    .prefetch_related("skills", "services")
                )

                for caregiver in caregivers.iterator(chunk_size=1000):
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
                            item.name
                            for item in caregiver.skills.all()
                        ],
                        "services": [
                            item.name
                            for item in caregiver.services.all()
                        ],
                    }

                    session.execute_write(self.write_caregiver, record)
                    caregiver_count += 1

                # 2. Synchronize Client records.
                clients = (
                    Client.objects
                    .select_related("location")
                    .prefetch_related("required_services")
                )

                for client in clients.iterator(chunk_size=1000):
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

                    session.execute_write(self.write_client, record)
                    client_count += 1

                # 3. Synchronize family care profiles.
                family_profiles = (
                    FamilyCareProfile.objects
                    .select_related("account")
                    .prefetch_related(
                        "required_services",
                        "required_skills",
                    )
                )

                for profile in family_profiles.iterator(chunk_size=1000):
                    record = {
                        # Use the Django primary key as the graph identifier.
                        "profile_id": str(profile.pk),
                        "care_recipient_age": profile.care_recipient_age,
                        "care_recipient_gender": (
                            profile.care_recipient_gender
                        ),
                        "care_level": profile.care_level,
                        "care_arrangement": profile.care_arrangement,
                        # FamilyCareProfile.location is text, not a relation.
                        "location": (profile.location or "").strip(),
                        "services": [
                            item.name
                            for item in profile.required_services.all()
                        ],
                        "skills": [
                            item.name
                            for item in profile.required_skills.all()
                        ],
                    }

                    session.execute_write(
                        self.write_family_profile,
                        record,
                    )
                    family_profile_count += 1

            self.stdout.write(
                self.style.SUCCESS(
                    f"Neo4j sync complete: {caregiver_count} caregivers, "
                    f"{client_count} clients and "
                    f"{family_profile_count} family profiles processed."
                )
            )

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

        tx.run("""
            CREATE CONSTRAINT family_profile_id_unique IF NOT EXISTS
            FOR (p:FamilyCareProfile)
            REQUIRE p.profile_id IS UNIQUE
        """).consume()

    @staticmethod
    def write_caregiver(tx, record):
        # Create or update the caregiver.
        tx.run("""
            MERGE (c:Caregiver {caregiver_id: $caregiver_id})
            SET c.age = $age,
                c.gender = $gender,
                c.experience_years = $experience_years,
                c.rating = $rating,
                c.availability = $availability,
                c.is_verified = $is_verified
        """, record).consume()

        # Replace the caregiver's location.
        tx.run("""
            MATCH (c:Caregiver {caregiver_id: $caregiver_id})
            OPTIONAL MATCH (c)-[old:LOCATED_IN]->(:Location)
            DELETE old
        """, record).consume()

        tx.run("""
            MATCH (c:Caregiver {caregiver_id: $caregiver_id})
            MERGE (l:Location {name: $location})
            MERGE (c)-[:LOCATED_IN]->(l)
        """, record).consume()

        # Replace the caregiver's skills.
        tx.run("""
            MATCH (c:Caregiver {caregiver_id: $caregiver_id})
            OPTIONAL MATCH (c)-[old:HAS_SKILL]->(:Skill)
            DELETE old
        """, record).consume()

        tx.run("""
            MATCH (c:Caregiver {caregiver_id: $caregiver_id})
            UNWIND $skills AS skill_name
            MERGE (s:Skill {name: skill_name})
            MERGE (c)-[:HAS_SKILL]->(s)
        """, {
            "caregiver_id": record["caregiver_id"],
            "skills": record["skills"],
        }).consume()

        # Replace the services provided by the caregiver.
        tx.run("""
            MATCH (c:Caregiver {caregiver_id: $caregiver_id})
            OPTIONAL MATCH (c)-[old:PROVIDES]->(:Service)
            DELETE old
        """, record).consume()

        tx.run("""
            MATCH (c:Caregiver {caregiver_id: $caregiver_id})
            UNWIND $services AS service_name
            MERGE (s:Service {name: service_name})
            MERGE (c)-[:PROVIDES]->(s)
        """, {
            "caregiver_id": record["caregiver_id"],
            "services": record["services"],
        }).consume()

    @staticmethod
    def write_client(tx, record):
        # Create or update the client.
        tx.run("""
            MERGE (c:Client {client_id: $client_id})
            SET c.age = $age,
                c.gender = $gender,
                c.care_level = $care_level
        """, record).consume()

        # Replace the client's location.
        tx.run("""
            MATCH (c:Client {client_id: $client_id})
            OPTIONAL MATCH (c)-[old:LOCATED_IN]->(:Location)
            DELETE old
        """, record).consume()

        tx.run("""
            MATCH (c:Client {client_id: $client_id})
            MERGE (l:Location {name: $location})
            MERGE (c)-[:LOCATED_IN]->(l)
        """, record).consume()

        # Replace the client's required services.
        tx.run("""
            MATCH (c:Client {client_id: $client_id})
            OPTIONAL MATCH (c)-[old:REQUIRES]->(:Service)
            DELETE old
        """, record).consume()

        tx.run("""
            MATCH (c:Client {client_id: $client_id})
            UNWIND $services AS service_name
            MERGE (s:Service {name: service_name})
            MERGE (c)-[:REQUIRES]->(s)
        """, {
            "client_id": record["client_id"],
            "services": record["services"],
        }).consume()

    @staticmethod
    def write_family_profile(tx, record):
        # Create or update the family profile.
        tx.run("""
            MERGE (p:FamilyCareProfile {profile_id: $profile_id})
            SET p.care_recipient_age = $care_recipient_age,
                p.care_recipient_gender = $care_recipient_gender,
                p.care_level = $care_level,
                p.care_arrangement = $care_arrangement
        """, record).consume()

        # Replace the profile's previous location relationship.
        tx.run("""
            MATCH (p:FamilyCareProfile {profile_id: $profile_id})
            OPTIONAL MATCH (p)-[old:LOCATED_IN]->(:Location)
            DELETE old
        """, record).consume()

        # Create a location relationship if a location is supplied.
        if record["location"]:
            tx.run("""
                MATCH (p:FamilyCareProfile {profile_id: $profile_id})
                MERGE (l:Location {name: $location})
                MERGE (p)-[:LOCATED_IN]->(l)
            """, record).consume()

        # Replace the profile's required services.
        tx.run("""
            MATCH (p:FamilyCareProfile {profile_id: $profile_id})
            OPTIONAL MATCH (p)-[old:REQUIRES]->(:Service)
            DELETE old
        """, record).consume()

        tx.run("""
            MATCH (p:FamilyCareProfile {profile_id: $profile_id})
            UNWIND $services AS service_name
            MERGE (s:Service {name: service_name})
            MERGE (p)-[:REQUIRES]->(s)
        """, record).consume()

        # Replace the profile's required skills.
        tx.run("""
            MATCH (p:FamilyCareProfile {profile_id: $profile_id})
            OPTIONAL MATCH (p)-[old:REQUIRES_SKILL]->(:Skill)
            DELETE old
        """, record).consume()

        tx.run("""
            MATCH (p:FamilyCareProfile {profile_id: $profile_id})
            UNWIND $skills AS skill_name
            MERGE (s:Skill {name: skill_name})
            MERGE (p)-[:REQUIRES_SKILL]->(s)
        """, record).consume()
