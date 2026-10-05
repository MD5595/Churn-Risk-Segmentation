# Churn Risk Segmentation
 
## Introduction
 
This project looks at a telecom company's customer base to determine who's most likely to leave and what should be done about it? Rather than just reporting an overall churn rate, this project tries to find out which customers are at risk, how much revenue they represents, and what can be done after determining why they're leaving.
 
The main dataset covers 7,043 customers, with fields spanning demographics, the services each customer subscribes to, their contract and billing setup, and category and reason for customers who've already churned. A second dataset maps zip codes to population, used later for a geographic view. Both files were sourced from the Maven Telecom Customer Churn dataset.
 
- `Churn.csv`: one row per customer: demographics, services (phone, internet, streaming, security add-ons), contract and payment details, monthly/total charges, and churn status/category/reason
- `Zipcodes.csv`: zip code, joined in for the dashboard's map view
## Approach
 
Data is stored in SQL Server, the deep analysis and modeling happen in Python, and the final output is an interactive Power BI dashboard.
 
### 1. Loading and cleaning the data
 
The raw CSVs are loaded into SQL Server as a starting table, then cleaned and validated in Python — checking nulls, duplicates, and data types, and handling a few genuine oddities along the way. Two oddities appeared.
 
- 120 customers (1.7%) had a negative Monthly Charge. Taking the absolute value turned out to be wrong on closer inspection: it produced customers with full internet service paying $1–9/month, which isn't realistic. These were instead imputed using the median charge for customers with the same phone/internet setup, and flagged with a `monthly_charge_imputed` column so the correction stays auditable rather than silent.
- "High value" needed a second look. My original definition (top quartile by total revenue) turned out to be mostly measuring tenure due to revenue accumulating over time. A long-tenured, low-spending customer and a brand-new high-spender could land in totally different quartiles than you'd expect. Switching to Monthly Charge (current spend, independent of tenure) gave a cleaner and more forward-looking definition of "valuable customer" . The two definitions only agree on 62% of customers.
### 2. Defining the core metrics
 
Revenue quartiles, churn rate, and revenue-at-risk were all built as reusable SQL views rather than one-off queries so they stay live as the underlying data changes. The high-value customer flag also gets defined.
 
### 3. Exploratory analysis
 
This stage looks at how churn varies across contract type, tenure, add-ons, internet type, payment method, offer, and age, then runs chi-square and t-tests to check whether the visible pattern is statistically meaningful. A few things stood out:
 
- Contract length is the single strongest churn driver by a wide margin
- Tenure and referral count are strong and simple loyalty signals
- Promotional Offer A looked like it reduced churn until controlling for contract type revealed that was almost entirely because Offer A customers were disproportionately already on two-year contracts
### 4. Building the risk model
 
A logistic regression model predicts each customer's probability of churning, using the features validated in the exploratory stage (contract, tenure, offer, internet type, payment method, referrals, add-on count, monthly charge). It scores 0.867 ROC-AUC, and every active customer gets a churn probability, a risk tier (Low/Medium/High), and a value tier (monthly charge quartile).
 
### 5. Quantifying the business impact
 
Rather than treating churn as a yes/no outcome, each active customer's annualized revenue is weighted by their individual churn probability to get an honest "expected revenue at risk" figure. This is also where the risk × value segment summary and the ranked priority list come from.
 
### 6. Dashboard
 
An interactive 4-page Power BI dashboard is used to display an executive overview, a risk segment drill-down with filters, why customers leave (churn category/reason), and a geographic view of all customers.
 
## Key Findings
 
- $738,721 in annual revenue is at risk among active customers (about 19% of active annualized revenue)
- Contract length dominates churn risk at every value level. High-value month-to-month customers churn at 58.2%, versus 20.1% (one-year) and 6.1% (two-year)
- The biggest area of dollar-weighted risk is the Q3 risk tier, not Q4 (the top value tier) since the very highest spenders tend to also be longer-tenured and better retained
- Medium Risk customers carry nearly half of all revenue at risk and are more cost-effective to retain than customers who are already High Risk
- Competitors are the leading cause of churn, ahead of service or price complaints
Full findings, caveats, and recommendations are in Findings.md
 
## Tools
 
| Tool | Role |
|---|---|
| SQL Server | Views for metrics, quartiles, and risk-weighted revenue |
| Python (pandas, scikit-learn, scipy, matplotlib) | Cleaning, exploratory analysis, statistical testing, churn model |
| Power BI | 4-page interactive dashboard |
 
## File order
 
Run the scripts in the order below.
 
1. `load_data.py`
2. `clean_and_validate.py`
3. `fix_monthly_charge.sql`
4. `create_features.py`
5. `03_revenue_and_churn_views.sql`
6. `03b_monthly_charge_quartile_comparison.sql`
7. `exploratory_analysis.py`
8. `risk_modeling.py`
9. `risk_weighted_revenue.sql`