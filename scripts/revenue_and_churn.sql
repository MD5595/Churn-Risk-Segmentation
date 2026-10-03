-- ============================================================
-- Step 3 (SQL Server / SSMS version)
-- Revenue percentiles, top-quartile flag, churn rate, and
-- revenue-at-risk, saved as reusable views.
--
-- NOTE ON "HIGH VALUE" DEFINITION:
-- Total Revenue is confounded with tenure (it accumulates over
-- time), so sorting by it mostly separates long-tenured
-- customers rather than genuinely high-value ones. Monthly
-- Charge reflects current spend and is not tenure-dependent, so
-- it's used as the PRIMARY "high value" definition below.
-- The Total Revenue quartile view is kept for comparison /
-- documentation of that finding, not as the basis for
-- "high value" going forward.
-- ============================================================

-- ------------------------------------------------------------
-- 1a. Monthly Charge quartiles (PRIMARY high-value definition)
-- ------------------------------------------------------------
IF OBJECT_ID('customers_with_charge_quartile', 'V') IS NOT NULL
    DROP VIEW customers_with_charge_quartile;
GO

CREATE VIEW customers_with_charge_quartile AS
SELECT
    *,
    NTILE(4) OVER (ORDER BY monthly_charge) AS charge_quartile,
    CASE
        WHEN NTILE(4) OVER (ORDER BY monthly_charge) = 4 THEN 1
        ELSE 0
    END AS is_high_value
FROM Churn_clean;
GO

-- Quick check: charge cutoff per quartile
SELECT
    charge_quartile,
    COUNT(*) AS customer_count,
    ROUND(MIN(monthly_charge), 2) AS min_charge,
    ROUND(MAX(monthly_charge), 2) AS max_charge,
    ROUND(AVG(monthly_charge), 2) AS avg_charge,
    ROUND(AVG(CAST(tenure_in_months AS FLOAT)), 1) AS avg_tenure_months
FROM customers_with_charge_quartile
GROUP BY charge_quartile
ORDER BY charge_quartile;
GO


-- ------------------------------------------------------------
-- 1b. Total Revenue quartiles (kept for comparison only —
-- confounded with tenure, see note above)
-- ------------------------------------------------------------
IF OBJECT_ID('customers_with_revenue_quartile', 'V') IS NOT NULL
    DROP VIEW customers_with_revenue_quartile;
GO

CREATE VIEW customers_with_revenue_quartile AS
SELECT
    *,
    NTILE(4) OVER (ORDER BY total_revenue) AS revenue_quartile,
    CASE
        WHEN NTILE(4) OVER (ORDER BY total_revenue) = 4 THEN 1
        ELSE 0
    END AS is_top_revenue_quartile
FROM Churn_clean;
GO

SELECT
    revenue_quartile,
    COUNT(*) AS customer_count,
    ROUND(MIN(total_revenue), 2) AS min_revenue,
    ROUND(MAX(total_revenue), 2) AS max_revenue,
    ROUND(AVG(total_revenue), 2) AS avg_revenue,
    ROUND(AVG(CAST(tenure_in_months AS FLOAT)), 1) AS avg_tenure_months
FROM customers_with_revenue_quartile
GROUP BY revenue_quartile
ORDER BY revenue_quartile;
GO


-- ------------------------------------------------------------
-- 2. Overall churn rate
-- ------------------------------------------------------------
IF OBJECT_ID('churn_rate_overall', 'V') IS NOT NULL
    DROP VIEW churn_rate_overall;
GO

CREATE VIEW churn_rate_overall AS
SELECT
    COUNT(*) AS total_customers,
    SUM(CAST(churn_flag AS INT)) AS churned_customers,
    ROUND(100.0 * SUM(CAST(churn_flag AS INT)) / COUNT(*), 2) AS churn_rate_pct
FROM Churn_clean;
GO

SELECT * FROM churn_rate_overall;
GO


-- ------------------------------------------------------------
-- 3. Churn rate by Monthly Charge quartile (primary view)
-- ------------------------------------------------------------
IF OBJECT_ID('churn_rate_by_quartile', 'V') IS NOT NULL
    DROP VIEW churn_rate_by_quartile;
GO

CREATE VIEW churn_rate_by_quartile AS
SELECT
    charge_quartile,
    COUNT(*) AS total_customers,
    SUM(CAST(churn_flag AS INT)) AS churned_customers,
    ROUND(100.0 * SUM(CAST(churn_flag AS INT)) / COUNT(*), 2) AS churn_rate_pct
FROM customers_with_charge_quartile
GROUP BY charge_quartile;
GO

SELECT * FROM churn_rate_by_quartile ORDER BY charge_quartile;
GO


-- ------------------------------------------------------------
-- 4. Revenue at risk: already lost to churn, by Monthly Charge
-- quartile
-- ------------------------------------------------------------
IF OBJECT_ID('revenue_at_risk_by_quartile', 'V') IS NOT NULL
    DROP VIEW revenue_at_risk_by_quartile;
GO

CREATE VIEW revenue_at_risk_by_quartile AS
SELECT
    charge_quartile,
    COUNT(*) AS churned_customers,
    ROUND(SUM(total_revenue), 2) AS revenue_lost,
    ROUND(AVG(total_revenue), 2) AS avg_revenue_per_churned_customer
FROM customers_with_charge_quartile
WHERE churn_flag = 1
GROUP BY charge_quartile;
GO

SELECT * FROM revenue_at_risk_by_quartile ORDER BY charge_quartile;
GO


-- ------------------------------------------------------------
-- 5. Forward-looking value at risk among CURRENTLY ACTIVE
-- high-value customers — annualized recurring revenue, since
-- these customers haven't churned yet and lifetime Total
-- Revenue isn't a future-loss figure.
-- ------------------------------------------------------------
IF OBJECT_ID('active_high_value_revenue', 'V') IS NOT NULL
    DROP VIEW active_high_value_revenue;
GO

CREATE VIEW active_high_value_revenue AS
SELECT
    COUNT(*) AS active_high_value_customers,
    ROUND(SUM(monthly_charge), 2) AS active_monthly_revenue,
    ROUND(SUM(monthly_charge) * 12, 2) AS annualized_revenue_at_risk
FROM customers_with_charge_quartile
WHERE is_high_value = 1
  AND churn_flag = 0;
GO

SELECT * FROM active_high_value_revenue;
GO


-- ------------------------------------------------------------
-- 6. Churn rate by contract type, within high-value customers
-- ------------------------------------------------------------
IF OBJECT_ID('churn_by_contract_high_value', 'V') IS NOT NULL
    DROP VIEW churn_by_contract_high_value;
GO

CREATE VIEW churn_by_contract_high_value AS
SELECT
    contract,
    COUNT(*) AS total_customers,
    SUM(CAST(churn_flag AS INT)) AS churned_customers,
    ROUND(100.0 * SUM(CAST(churn_flag AS INT)) / COUNT(*), 2) AS churn_rate_pct,
    ROUND(SUM(CASE WHEN churn_flag = 1 THEN total_revenue ELSE 0 END), 2) AS revenue_lost
FROM customers_with_charge_quartile
WHERE is_high_value = 1
GROUP BY contract;
GO

SELECT * FROM churn_by_contract_high_value ORDER BY churn_rate_pct DESC;
GO


-- ------------------------------------------------------------
-- 7. Overlap between the two "high value" definitions
-- (documents the finding: how much they agree/disagree)
-- ------------------------------------------------------------
SELECT
    rq.is_top_revenue_quartile AS top_by_total_revenue,
    cq.is_high_value AS top_by_monthly_charge,
    COUNT(*) AS customer_count
FROM customers_with_revenue_quartile rq
JOIN customers_with_charge_quartile cq
    ON rq.customer_id = cq.customer_id
GROUP BY rq.is_top_revenue_quartile, cq.is_high_value
ORDER BY top_by_total_revenue DESC, top_by_monthly_charge DESC;
GO
