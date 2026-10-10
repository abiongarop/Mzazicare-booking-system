import csv
from pathlib import Path

from django.core.management.base import BaseCommand, CommandError
from django.db import transaction

from caregivers.models import Caregiver, Location, Skill, Service
from clients.models import Client


PROJECT_ROOT = Path(__file__).resolve().parents[4]
DATA_DIR = PROJECT_ROOT / "data" / "processed"


def read_csv(filename):
    path = DATA_DIR / filename

    if not path.exists():
        raise CommandError(f"CSV file not found: {path}")

    with path.open("r", encoding="utf-8-sig", newline="") as file:
        return list(csv.DictReader(file))


def required(row, field, filename):
    value = row.get(field)
    if value is None or not str(value).strip():
        raise CommandError(
            f"Missing '{field}' in {filename}: {row}"
        )
    return str(value).strip()


class Command(BaseCommand):
    help = "Import MzaziCare synthetic CSV records"

    @transaction.atomic
    def handle(self, *args, **options):
        caregivers = read_csv("caregivers.csv")
        clients = read_csv("clients.csv")
        skills = read_csv("caregiver_skills.csv")
        services = read_csv("caregiver_services.csv")
        needs = read_csv("client_needs.csv")

        for row in caregivers:
            location_name = required(
                row, "location", "caregivers.csv"
            )
            location, _ = Location.objects.get_or_create(
                name=location_name
            )

            caregiver_id = required(
                row, "caregiver_id", "caregivers.csv"
            )

            Caregiver.objects.update_or_create(
                caregiver_id=caregiver_id,
                defaults={
                    "age": int(row["age"]),
                    "gender": row.get("gender", ""),
                    "experience_years": int(
                        row.get("experience_years") or 0
                    ),
                    "rating": float(row.get("rating") or 0),
                    "location": location,
                    "availability": row.get("availability", ""),
                },
            )

        for row in clients:
            location_name = required(
                row, "location", "clients.csv"
            )
            location, _ = Location.objects.get_or_create(
                name=location_name
            )

            client_id = required(
                row, "client_id", "clients.csv"
            )

            Client.objects.update_or_create(
                client_id=client_id,
                defaults={
                    "age": int(row["age"]),
                    "gender": row.get("gender", ""),
                    "location": location,
                    "care_level": row.get("care_level", ""),
                },
            )

        for row in skills:
            caregiver_id = required(
                row, "caregiver_id", "caregiver_skills.csv"
            )
            skill_name = required(
                row, "skill", "caregiver_skills.csv"
            )

            caregiver = Caregiver.objects.get(
                caregiver_id=caregiver_id
            )
            skill, _ = Skill.objects.get_or_create(
                name=skill_name
            )
            caregiver.skills.add(skill)

        for row in services:
            caregiver_id = required(
                row, "caregiver_id", "caregiver_services.csv"
            )
            service_name = required(
                row, "service", "caregiver_services.csv"
            )

            caregiver = Caregiver.objects.get(
                caregiver_id=caregiver_id
            )
            service, _ = Service.objects.get_or_create(
                name=service_name
            )
            caregiver.services.add(service)

        for row in needs:
            client_id = required(
                row, "client_id", "client_needs.csv"
            )
            service_name = required(
                row, "service", "client_needs.csv"
            )

            client = Client.objects.get(client_id=client_id)
            service, _ = Service.objects.get_or_create(
                name=service_name
            )
            client.required_services.add(service)

        self.stdout.write(
            self.style.SUCCESS(
                f"Imported {Caregiver.objects.count()} caregivers, "
                f"{Client.objects.count()} clients, "
                f"{Skill.objects.count()} skills and "
                f"{Service.objects.count()} services."
            )
        )
