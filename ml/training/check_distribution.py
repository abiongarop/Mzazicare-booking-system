import pandas as pd
import os

print("SCRIPT STARTED")

print("Current folder:", os.getcwd())
print("Files in folder:", os.listdir())

csv_file = "recommendation_training.csv"

if not os.path.exists(csv_file):
    print(f"\nCSV NOT FOUND: {csv_file}")
else:
    df = pd.read_csv(csv_file)

    print("\nCOLUMNS:", df.columns.tolist())
    print("TOTAL RECORDS:", len(df))

    if "suitable" in df.columns:
        counts = df["suitable"].value_counts()
        percentages = df["suitable"].value_counts(normalize=True) * 100

        print("\nSUITABILITY DISTRIBUTION")
        print("Suitable (1):", counts.get(1, 0),
              f"({percentages.get(1, 0):.2f}%)")
        print("Unsuitable (0):", counts.get(0, 0),
              f"({percentages.get(0, 0):.2f}%)")
    else:
        print("\nThe 'suitable' column was not found.")