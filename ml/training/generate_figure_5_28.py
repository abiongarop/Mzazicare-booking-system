
import pandas as pd
from sklearn.model_selection import train_test_split

# Load the prepared dataset
df = pd.read_csv("recommendation_training.csv")

# Separate features and suitability label
X = df.drop(columns=["suitability"])
y = df["suitability"]

# Split into training and test sets
X_train, X_test, y_train, y_test = train_test_split(
    X,
    y,
    test_size=0.20,
    random_state=42,
    stratify=y
)

print("DATASET PARTITIONING")
print("-" * 45)

for name, labels in [
    ("Training", y_train),
    ("Test", y_test)
]:
    print(f"\n{name} set")
    print("Total records:", len(labels))
    print("Class counts:")
    print(labels.value_counts().sort_index().rename(
        index={0: "Unsuitable", 1: "Suitable"}
    ).to_string())

print("\nTOTAL RECORDS:", len(df))
print("TRAINING RECORDS:", len(X_train))
print("TEST RECORDS:", len(X_test))
