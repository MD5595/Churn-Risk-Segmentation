
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from sqlalchemy import create_engine
from sklearn.model_selection import train_test_split
from sklearn.linear_model import LogisticRegression
from sklearn.preprocessing import StandardScaler
from sklearn.metrics import roc_auc_score, roc_curve, classification_report, confusion_matrix

SERVER = r"MD\SQLEXPRESS"
DATABASE = "TelecomChurn"   # confirm this matches your actual database name

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
df["churn_flag"] = df["churn_flag"].astype(int)

print(f"Loaded {len(df):,} rows")


categorical_features = ["contract", "internet_type", "offer", "payment_method", "paperless_billing"]
numeric_features = ["tenure_in_months", "monthly_charge", "number_of_referrals", "addon_count"]

model_df = df[["customer_id", "churn_flag"] + categorical_features + numeric_features].copy()


model_df["offer"] = model_df["offer"].fillna("No Offer")
model_df["internet_type"] = model_df["internet_type"].fillna("No Internet")

before = len(model_df)
model_df = model_df.dropna()
print(f"Rows available for modeling: {len(model_df):,} (dropped {before - len(model_df)} rows with genuine missing data)")

X = pd.get_dummies(model_df[categorical_features + numeric_features], columns=categorical_features, drop_first=True)
y = model_df["churn_flag"]
customer_ids = model_df["customer_id"]

print(f"Features used: {X.columns.tolist()}")


X_train, X_test, y_train, y_test, id_train, id_test = train_test_split(
    X, y, customer_ids, test_size=0.25, random_state=42, stratify=y
)

scaler = StandardScaler()
X_train_scaled = X_train.copy()
X_test_scaled = X_test.copy()
X_train_scaled[numeric_features] = scaler.fit_transform(X_train[numeric_features])
X_test_scaled[numeric_features] = scaler.transform(X_test[numeric_features])



model = LogisticRegression(max_iter=1000, random_state=42)
model.fit(X_train_scaled, y_train)

# Predictions
y_pred = model.predict(X_test_scaled)
y_proba = model.predict_proba(X_test_scaled)[:, 1]

auc = roc_auc_score(y_test, y_proba)
print(f"\n=== Model Performance ===")
print(f"ROC-AUC: {auc:.3f}")
print("\nClassification Report:")
print(classification_report(y_test, y_pred))
print("Confusion Matrix:")
print(confusion_matrix(y_test, y_pred))

fpr, tpr, _ = roc_curve(y_test, y_proba)
plt.figure(figsize=(6, 5))
plt.plot(fpr, tpr, label=f"AUC = {auc:.3f}", color="steelblue")
plt.plot([0, 1], [0, 1], linestyle="--", color="gray")
plt.xlabel("False Positive Rate")
plt.ylabel("True Positive Rate")
plt.title("ROC Curve - Churn Model")
plt.legend()
plt.tight_layout()
plt.savefig("Visuals/roc_curve.png", dpi=100)
plt.close()

coef_df = pd.DataFrame({
    "feature": X.columns,
    "coefficient": model.coef_[0]
}).sort_values("coefficient", key=abs, ascending=False)

print("\n=== Feature Importance (Logistic Regression Coefficients) ===")
print(coef_df.to_string(index=False))


plt.figure(figsize=(8, 6))
plt.barh(coef_df["feature"], coef_df["coefficient"], color="steelblue")
plt.xlabel("Coefficient (impact on churn log-odds)")
plt.title("Feature Importance")
plt.tight_layout()
plt.savefig("Visuals/feature_importance.png", dpi=100)
plt.close()



X_full_scaled = X.copy()
X_full_scaled[numeric_features] = scaler.transform(X[numeric_features])

model_df["churn_probability"] = model.predict_proba(X_full_scaled)[:, 1]

def risk_tier(p):
    if p >= 0.7:
        return "High Risk"
    elif p >= 0.4:
        return "Medium Risk"
    else:
        return "Low Risk"

model_df["risk_tier"] = model_df["churn_probability"].apply(risk_tier)

model_df["value_tier"] = pd.qcut(model_df["monthly_charge"], 4, labels=["Q1", "Q2", "Q3", "Q4 (High Value)"])

print("\n=== Risk Tier Distribution ===")
print(model_df["risk_tier"].value_counts())

print("\n=== Risk x Value Tier Cross-tab ===")
print(pd.crosstab(model_df["value_tier"], model_df["risk_tier"]))



scored = model_df[["customer_id", "churn_probability", "risk_tier", "value_tier"]]
scored.to_sql("customer_risk_scores", engine, if_exists="replace", index=False)
print(f"\nWrote {len(scored):,} scored customers to customer_risk_scores table")

print("\nDone. Charts saved: roc_curve.png, feature_importance.png")

print(df.groupby("offer")["churn_flag"].mean())
print(pd.crosstab(df["offer"].fillna("No Offer"), df["contract"], normalize="index").round(2))
print(pd.crosstab(df["offer"].fillna("No Offer"), df["contract"], normalize="index").round(2))