-- ============================================================
-- Step 7: Risk-weighted revenue at risk, using the model's
-- churn_probability instead of the binary churn_flag.
-- Run after 06_risk_model.py has written customer_risk_scores.
-- ============================================================

-- ------------------------------------------------------------
-- 1. Combined view: customer details + model score
-- ------------------------------------------------------------
IF OBJECT_ID('customers_with_risk_score', 'V') IS NOT NULL
    DROP VIEW customers_with_risk_score;
GO

CREATE VIEW customers_with_risk_score AS
SELECT
    c.*,
    r.churn_probability,
    r.risk_tier,
    r.value_tier
FROM Churn_clean c
JOIN customer_risk_scores r
    ON c.customer_id = r.customer_id;
GO

SELECT TOP 10 customer_id, monthly_charge, churn_flag, churn_probability, risk_tier, value_tier
FROM customers_with_risk_score
ORDER BY churn_probability DESC;
GO


-- ------------------------------------------------------------
-- 2. Risk-weighted revenue at risk (per active customer)
-- Instead of a binary "churned or not," this multiplies each
-- ACTIVE customer's annual revenue by their predicted churn
-- probability -- a more realistic forward-looking exposure
-- figure than counting only customers who already left.
-- ------------------------------------------------------------
IF OBJECT_ID('risk_weighted_revenue_at_risk', 'V') IS NOT NULL
    DROP VIEW risk_weighted_revenue_at_risk;
GO

CREATE VIEW risk_weighted_revenue_at_risk AS
SELECT
    customer_id,
    contract,
    monthly_charge,
    ROUND(monthly_charge * 12, 2) AS annualized_revenue,
    churn_probability,
    risk_tier,
    value_tier,
    ROUND(monthly_charge * 12 * churn_probability, 2) AS expected_revenue_at_risk
FROM customers_with_risk_score
WHERE churn_flag = 0;  -- only active customers -- forward-looking exposure
GO

-- Total expected revenue at risk across all active customers
SELECT
    COUNT(*) AS active_customers,
    ROUND(SUM(annualized_revenue), 2) AS total_annualized_revenue,
    ROUND(SUM(expected_revenue_at_risk), 2) AS total_expected_revenue_at_risk
FROM risk_weighted_revenue_at_risk;
GO


-- ------------------------------------------------------------
-- 3. Risk x Value segment summary
-- The core "who's most likely to leave, what can we do" table --
-- shows customer count and revenue at risk for every combination
-- of risk tier and value tier.
-- ------------------------------------------------------------
IF OBJECT_ID('risk_value_segment_summary', 'V') IS NOT NULL
    DROP VIEW risk_value_segment_summary;
GO

CREATE VIEW risk_value_segment_summary AS
SELECT
    value_tier,
    risk_tier,
    COUNT(*) AS active_customers,
    ROUND(AVG(churn_probability), 3) AS avg_churn_probability,
    ROUND(SUM(monthly_charge * 12), 2) AS annualized_revenue,
    ROUND(SUM(monthly_charge * 12 * churn_probability), 2) AS expected_revenue_at_risk
FROM customers_with_risk_score
WHERE churn_flag = 0
GROUP BY value_tier, risk_tier;
GO

SELECT * FROM risk_value_segment_summary
ORDER BY
    CASE value_tier WHEN 'Q4 (High Value)' THEN 1 WHEN 'Q3' THEN 2 WHEN 'Q2' THEN 3 ELSE 4 END,
    CASE risk_tier WHEN 'High Risk' THEN 1 WHEN 'Medium Risk' THEN 2 ELSE 3 END;
GO


-- ------------------------------------------------------------
-- 4. Priority list: your sharpest target group --
-- High Value + High Risk, ranked by expected revenue at risk
-- ------------------------------------------------------------
SELECT TOP 25
    customer_id,
    contract,
    monthly_charge,
    ROUND(monthly_charge * 12, 2) AS annualized_revenue,
    churn_probability,
    ROUND(monthly_charge * 12 * churn_probability, 2) AS expected_revenue_at_risk
FROM customers_with_risk_score
WHERE churn_flag = 0
  AND value_tier = 'Q4 (High Value)'
  AND risk_tier = 'High Risk'
ORDER BY expected_revenue_at_risk DESC;
GO
