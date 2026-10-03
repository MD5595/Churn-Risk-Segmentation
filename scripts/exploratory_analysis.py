
import pandas as pd
import matplotlib.pyplot as plt
from sqlalchemy import create_engine
from scipy import stats


SERVER = "MD\SQLEXPRESS"
DATABASE = "TelecomChurn"

engine = create_engine(
    f"mssql+pyodbc://@{SERVER}/{DATABASE}?driver=ODBC+Driver+17+for+SQL+Server&trusted_connection=yes"
)

df = pd.read_sql("SELECT * FROM Churn_clean", engine)
df.columns = (
    df.columns
    .str.strip()
    .str.lower()
    .str.replace(r"[^a-z0-9]+", "_", regex=True)
    .str.strip("_")
)
print(f"Loaded {len(df):,} rows, {len(df.columns)} columns")

df["churn_flag"] = df["churn_flag"].astype(int)


def churn_rate_by_category(df, col, min_count=20):
    summary = (
        df.groupby(col)
        .agg(total=("churn_flag", "count"), churned=("churn_flag", "sum"))
        .assign(churn_rate_pct=lambda x: round(100 * x["churned"] / x["total"], 2))
        .query("total >= @min_count")
        .sort_values("churn_rate_pct", ascending=False)
    )
    print(f"\n--- Churn rate by {col} ---")
    print(summary)

    ax = summary["churn_rate_pct"].plot(kind="bar", figsize=(7, 4), color="steelblue")
    ax.set_ylabel("Churn rate (%)")
    ax.set_title(f"Churn rate by {col}")
    plt.xticks(rotation=45, ha="right")
    plt.tight_layout()
    plt.savefig(f"churn_by_{col}.png", dpi=100)
    plt.close()

    return summary



segment_cols = [
    "contract", "internet_type", "offer", "payment_method",
    "tenure_band", "age_band", "addon_count", "paperless_billing",
]

results = {}
for col in segment_cols:
    if col in df.columns:
        results[col] = churn_rate_by_category(df, col)
    else:
        print(f"Column '{col}' not found — skipping (check exact name in Churn_clean)")


churned = df[df["churn_flag"] == 1]

print("\n--- Churn Category breakdown ---")
print(churned["churn_category"].value_counts())

print("\n--- Top Churn Reasons ---")
print(churned["churn_reason"].value_counts().head(15))

ax = churned["churn_category"].value_counts().plot(kind="barh", figsize=(7, 4), color="indianred")
ax.set_xlabel("Number of churned customers")
ax.set_title("Churn Category breakdown")
plt.tight_layout()
plt.savefig("../Visuals/churn_category_breakdown.png", dpi=100)
plt.close()



def chi_square_test(df, col):
    contingency = pd.crosstab(df[col], df["churn_flag"])
    chi2, p, dof, expected = stats.chi2_contingency(contingency)
    print(f"\nChi-square test: churn vs {col}")
    print(f"  chi2 = {chi2:.2f}, p-value = {p:.6f}, dof = {dof}")
    if p < 0.05:
        print("  -> Statistically significant association (p < 0.05)")
    else:
        print("  -> No significant association (p >= 0.05)")
    return chi2, p


categorical_to_test = ["contract", "internet_type", "offer", "payment_method", "paperless_billing"]
for col in categorical_to_test:
    if col in df.columns:
        chi_square_test(df, col)


def t_test(df, col):
    churned_vals = df.loc[df["churn_flag"] == 1, col].dropna()
    stayed_vals = df.loc[df["churn_flag"] == 0, col].dropna()
    t_stat, p = stats.ttest_ind(churned_vals, stayed_vals, equal_var=False)
    print(f"\nT-test: {col} (churned vs. stayed)")
    print(f"  Churned mean = {churned_vals.mean():.2f}, Stayed mean = {stayed_vals.mean():.2f}")
    print(f"  t = {t_stat:.2f}, p-value = {p:.6f}")
    if p < 0.05:
        print("  -> Statistically significant difference (p < 0.05)")
    else:
        print("  -> No significant difference (p >= 0.05)")
    return t_stat, p


numeric_to_test = ["monthly_charge", "tenure_in_months", "addon_count", "number_of_referrals"]
for col in numeric_to_test:
    if col in df.columns:
        t_test(df, col)

print("\nDone. Charts saved as PNG files in the current folder.")
