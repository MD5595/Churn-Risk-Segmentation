import pandas as pd
import sqlite3

df = pd.read_csv("../churn.csv")

df["tenure_band"] = pd.cut(
    df["Tenure in Months"],
    bins=[-1, 6, 12, 24, 48, 100],
    labels=["0-6 mo", "7-12 mo", "13-24 mo", "25-48 mo", "49+ mo"]
)
df["age_band"] = pd.cut(
    df["Age"],
    bins=[17, 24, 34, 44, 54, 64, 100],
    labels=["18-24", "25-34", "35-44", "45-54", "55-64", "65+"]
)
addon_cols = [
    "Online Security", "Online Backup", "Device Protection Plan",
    "Premium Tech Support", "Streaming TV", "Streaming Movies",
    "Streaming Music", "Unlimited Data"
]
df["addon_count"] = (df[addon_cols] == "Yes").sum(axis=1)
df["churn_flag"] = (df["Customer Status"] == "Churned").astype(int)

print(df.columns.tolist())
print(df[["tenure_band", "age_band", "addon_count", "churn_flag"]].head())
conn = sqlite3.connect("../churn.db")
df.to_sql("customers_clean", conn, if_exists="replace", index=False)
conn.close()

df.to_csv("customers_clean.csv", index=False)