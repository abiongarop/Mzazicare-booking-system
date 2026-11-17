
from pathlib import Path
import pandas as pd

print("FIGURE 5.27 SCRIPT STARTED", flush=True)

# Get the project root directory
ROOT = Path(__file__).resolve().parents[2]
DATA_DIR = ROOT / "data" / "processed"
TRAINING_FILE = Path(__file__).resolve().parent / "recommendation_training.csv"

# Load the original datasets
caregivers = pd.read_csv(DATA_DIR / "caregivers.csv")
clients = pd.read_csv(DATA_DIR / "clients.csv")
caregiver_skills = pd.read_csv(DATA_DIR / "caregiver_skills.csv")
caregiver_services = pd.read_csv(DATA_DIR / "caregiver_services.csv")
client_needs = pd.read_csv(DATA_DIR / "client_needs.csv")

# Load the prepared recommendation dataset
training = pd.read_csv(TRAINING_FILE)

print("\n--- RAW CAREGIVER RECORDS ---")
print(caregivers.head(3).to_string(index=False))

print("\n--- RAW CLIENT RECORDS ---")
print(clients.head(3).to_string(index=False))

print("\n--- RAW CAREGIVER SKILLS ---")
print(caregiver_skills.head(3).to_string(index=False))

print("\n--- RAW CAREGIVER SERVICES ---")
print(caregiver_services.head(3).to_string(index=False))

print("\n--- RAW CLIENT NEEDS ---")
print(client_needs.head(3).to_string(index=False))

print("\n--- EXTRACTED RECOMMENDATION FEATURES ---")
print(training.head(3).to_string(index=False))

print("\nFIGURE 5.27 OUTPUT COMPLETED")
