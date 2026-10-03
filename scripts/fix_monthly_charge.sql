-- ============================================================
-- Revised fix for Monthly Charge (table: Churn_clean)
--
-- The earlier fix (ABS()) assumed only the SIGN was wrong.
-- But the resulting values (now $1-$9/month) are implausible for
-- customers with Phone Service + Internet Service, so the
-- MAGNITUDE was probably wrong too, not just the sign.
--
-- Better approach: flag these ~120 rows and replace them with
-- the median Monthly Charge for customers with the same
-- Phone Service / Internet Service combination.
-- ============================================================

-- 1. Identify the suspect rows
SELECT customer_id, monthly_charge, phone_service, internet_service, internet_type
FROM Churn_clean
WHERE monthly_charge < 18
ORDER BY monthly_charge;

-- 2. Preview the replacement values (median charge per segment)
SELECT DISTINCT
    phone_service,
    internet_service,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY monthly_charge)
        OVER (PARTITION BY phone_service, internet_service) AS median_charge
FROM Churn_clean
WHERE monthly_charge >= 18;

-- 3. Add a flag column (safe to skip if it already exists —
-- check Object Explorer > Churn_clean > Columns first)
IF NOT EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID('Churn_clean') AND name = 'monthly_charge_imputed'
)
BEGIN
    ALTER TABLE Churn_clean ADD monthly_charge_imputed BIT NOT NULL DEFAULT 0;
END
GO

UPDATE Churn_clean
SET monthly_charge_imputed = 1
WHERE monthly_charge < 18;
GO

-- 4. Replace the suspect values with the segment median
;WITH medians AS (
    SELECT DISTINCT
        phone_service,
        internet_service,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY monthly_charge)
            OVER (PARTITION BY phone_service, internet_service) AS median_charge
    FROM Churn_clean
    WHERE monthly_charge_imputed = 0
)
UPDATE c
SET c.monthly_charge = m.median_charge
FROM Churn_clean c
JOIN medians m
    ON c.phone_service = m.phone_service
   AND c.internet_service = m.internet_service
WHERE c.monthly_charge_imputed = 1;
GO

-- 5. Confirm the fix
SELECT MIN(monthly_charge) AS min_charge, COUNT(*) AS still_under_18
FROM Churn_clean
WHERE monthly_charge < 18;

SELECT COUNT(*) AS imputed_row_count
FROM Churn_clean
WHERE monthly_charge_imputed = 1;

-- After this, update 03_revenue_and_churn_views_ssms.sql to use
-- Churn_clean (not customers_clean) and re-run it.
