-- Payment SLA & Aging Analysis (SQLite)
-- Dummy data only. Tables: payments, approvers
-- Report date used for aging: 2026-11-10

-- Q1. SELECT / WHERE: high-value pending payments (> Rs 1,00,000), oldest first
-- Basic filtering and sorting to find items that need attention.
SELECT payment_id, business_unit, payment_type, amount_inr, received_date
FROM payments
WHERE status = 'Pending'
  AND amount_inr > 100000
ORDER BY received_date ASC
LIMIT 10;

-- Q2. GROUP BY: payment count and value by status
-- Quick snapshot of the whole workload.
SELECT status,
       COUNT(*)                AS payment_count,
       ROUND(SUM(amount_inr),0) AS total_amount_inr
FROM payments
GROUP BY status
ORDER BY payment_count DESC;

-- Q3. GROUP BY + CASE: SLA compliance % by business unit (completed payments only)
-- SLA is met when processed within sla_days of receipt.
SELECT business_unit,
       COUNT(*) AS completed,
       SUM(CASE WHEN julianday(processed_date) - julianday(received_date) <= sla_days THEN 1 ELSE 0 END) AS within_sla,
       ROUND(100.0 * SUM(CASE WHEN julianday(processed_date) - julianday(received_date) <= sla_days THEN 1 ELSE 0 END) / COUNT(*), 1) AS sla_pct
FROM payments
WHERE status = 'Completed' AND processed_date IS NOT NULL
GROUP BY business_unit
ORDER BY sla_pct ASC;

-- Q4. JOIN: each payment with its approver's name and region
-- INNER JOIN between payments and the approvers table.
SELECT p.payment_id, p.business_unit, a.approver_name, a.region, p.amount_inr, p.status
FROM payments p
JOIN approvers a ON a.approver_id = p.approver_id
ORDER BY p.amount_inr DESC
LIMIT 10;

-- Q5. JOIN + GROUP BY: pending workload per approver
-- Shows which approvers' items are waiting, useful for follow-ups.
SELECT a.approver_name, a.business_unit,
       COUNT(*)                  AS pending_count,
       ROUND(SUM(p.amount_inr),0) AS pending_value_inr
FROM payments p
JOIN approvers a ON a.approver_id = p.approver_id
WHERE p.status = 'Pending'
GROUP BY a.approver_id, a.approver_name, a.business_unit
ORDER BY pending_count DESC;

-- Q6. Aging calculation: open payments by aging bucket (as of 10-Nov-2026)
-- Aging = days between received_date and the report date. CASE creates the buckets.
SELECT CASE
         WHEN age_days <= 1 THEN '0-1 days'
         WHEN age_days <= 3 THEN '2-3 days'
         WHEN age_days <= 7 THEN '4-7 days'
         ELSE '8+ days'
       END AS aging_bucket,
       COUNT(*) AS payments,
       ROUND(SUM(amount_inr),0) AS value_inr
FROM (
  SELECT amount_inr,
         CAST(julianday('2026-11-10') - julianday(received_date) AS INTEGER) AS age_days
  FROM payments
  WHERE status IN ('Pending','On Hold')
)
GROUP BY aging_bucket
ORDER BY MIN(age_days);

-- Q7. SLA breaches: completed payments that took longer than the SLA
-- Lists exceptions with the number of days delayed, for root-cause review.
SELECT payment_id, business_unit, received_date, processed_date,
       CAST(julianday(processed_date) - julianday(received_date) AS INTEGER) AS days_taken,
       CAST(julianday(processed_date) - julianday(received_date) AS INTEGER) - sla_days AS days_over_sla
FROM payments
WHERE status = 'Completed'
  AND processed_date IS NOT NULL
  AND julianday(processed_date) - julianday(received_date) > sla_days
ORDER BY days_over_sla DESC
LIMIT 10;

-- Q8. Monthly trend: volume, value and SLA % by month
-- strftime extracts the month for trend reporting.
SELECT strftime('%Y-%m', received_date) AS month,
       COUNT(*) AS payments_received,
       ROUND(SUM(amount_inr),0) AS total_value_inr,
       ROUND(100.0 * SUM(CASE WHEN status='Completed' AND julianday(processed_date)-julianday(received_date) <= sla_days THEN 1 ELSE 0 END)
             / NULLIF(SUM(CASE WHEN status='Completed' THEN 1 ELSE 0 END),0), 1) AS sla_pct
FROM payments
GROUP BY month
ORDER BY month;

-- Q9. HAVING: business units with SLA below 95%
-- HAVING filters after grouping, which WHERE cannot do.
SELECT business_unit,
       COUNT(*) AS completed,
       ROUND(100.0 * SUM(CASE WHEN julianday(processed_date)-julianday(received_date) <= sla_days THEN 1 ELSE 0 END) / COUNT(*), 1) AS sla_pct
FROM payments
WHERE status = 'Completed' AND processed_date IS NOT NULL
GROUP BY business_unit
HAVING sla_pct < 95
ORDER BY sla_pct;

-- Q10. Data validation: records with missing approver or missing processed date
-- Supports data integrity checks: finds payments with no approver, and completed payments with no processed date.
SELECT payment_id, status, approver_id, processed_date,
       CASE WHEN approver_id IS NULL THEN 'Missing approver'
            WHEN status = 'Completed' AND processed_date IS NULL THEN 'Completed but no processed date'
       END AS issue
FROM payments
WHERE approver_id IS NULL
   OR (status = 'Completed' AND processed_date IS NULL);
