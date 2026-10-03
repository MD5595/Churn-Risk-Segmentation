import pandas as pd
import sqlite3

df = pd.read_csv("../churn.csv")


print("=== NULLS ===")
null_counts = df.isnull().sum()
null_counts = null_counts[null_counts > 0]
print(null_counts if not null_counts.empty else "No nulls found.")


print("\n=== DUPLICATES ===")
dupe_ids = df["Customer ID"].duplicated().sum()
dupe_rows = df.duplicated().sum()
print(f"Duplicate Customer IDs: {dupe_ids}")
print(f"Fully duplicate rows:   {dupe_rows}")

if dupe_ids > 0:
    df = df.drop_duplicates(subset="Customer ID", keep="first")
    print(f"Dropped duplicates, {len(df):,} rows remain")


print("\n=== DATA TYPES ===")
print(df.dtypes)


print("\n=== ODDITIES ===")


neg_charge = df["Monthly Charge"] < 0
print(f"Negative Monthly Charge: {neg_charge.sum()}")
if neg_charge.sum() > 0:
    print(df.loc[neg_charge, ["Customer ID", "Monthly Charge"]])
    df.loc[neg_charge, "Monthly Charge"] = df.loc[neg_charge, "Monthly Charge"].abs()
    print("-> Fixed by taking absolute value (treated as sign error)")

for col in ["Total Charges", "Total Revenue", "Tenure in Months",
            "Avg Monthly GB Download", "Avg Monthly Long Distance Charges"]:
    bad = (df[col] < 0).sum()
    print(f"Negative {col}: {bad}")


bad_age = ~df["Age"].between(0, 110)
print(f"Out-of-range Age: {bad_age.sum()}")


conn = sqlite3.connect("../churn.db")
df.to_sql("customers_clean", conn, if_exists="replace", index=False)

check = pd.read_sql("SELECT COUNT(*) AS n FROM customers_clean", conn)
print(f"\ncustomers_clean written: {check['n'][0]:,} rows")
conn.close()
