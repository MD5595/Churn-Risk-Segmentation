-- ============================================================
-- Compare "high value" defined by Total Revenue vs Monthly Charge
-- ============================================================

-- ------------------------------------------------------------
-- 1. Monthly Charge quartiles (current spend, not accumulated)
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
    END AS is_top_charge_quartile
FROM Churn_clean;
GO

-- Churn rate by Monthly Charge quartile
SELECT
    charge_quartile,
    COUNT(*) AS total_customers,
    SUM(CAST(churn_flag AS INT)) AS churned_customers,
    ROUND(100.0 * SUM(CAST(churn_flag AS INT)) / COUNT(*), 2) AS churn_rate_pct,
    ROUND(AVG(CAST(tenure_in_months AS FLOAT)), 1) AS avg_tenure_months
FROM customers_with_charge_quartile
GROUP BY charge_quartile
ORDER BY charge_quartile;
GO


-- ------------------------------------------------------------
-- 2. Overlap: how many customers are top-quartile under BOTH
-- definitions vs. only one?
-- ------------------------------------------------------------
SELECT
    r.is_top_quartile AS top_by_total_revenue,
    c.is_top_charge_quartile AS top_by_monthly_charge,
    COUNT(*) AS customer_count
FROM customers_with_quartile r
JOIN customers_with_charge_quartile c
    ON r.customer_id = c.customer_id
GROUP BY r.is_top_quartile, c.is_top_charge_quartile
ORDER BY top_by_total_revenue DESC, top_by_monthly_charge DESC;
GO

-- Same thing, framed as: of Total-Revenue-Q4 customers, how many
-- are ALSO Monthly-Charge-Q4 vs. not?
SELECT
    COUNT(*) AS total_revenue_q4_customers,
    SUM(CASE WHEN c.is_top_charge_quartile = 1 THEN 1 ELSE 0 END) AS also_top_by_charge,
    SUM(CASE WHEN c.is_top_charge_quartile = 0 THEN 1 ELSE 0 END) AS not_top_by_charge,
    ROUND(100.0 * SUM(CASE WHEN c.is_top_charge_quartile = 1 THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_overlap
FROM customers_with_quartile r
JOIN customers_with_charge_quartile c ON r.customer_id = c.customer_id
WHERE r.is_top_quartile = 1;
GO
