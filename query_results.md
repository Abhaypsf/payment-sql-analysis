# Query Results (sample data)

## Q1. SELECT / WHERE: high-value pending payments (> Rs 1,00,000), oldest first
*Basic filtering and sorting to find items that need attention.*

```sql
SELECT payment_id, business_unit, payment_type, amount_inr, received_date
FROM payments
WHERE status = 'Pending'
  AND amount_inr > 100000
ORDER BY received_date ASC
LIMIT 10;
```

| payment_id   | business_unit   | payment_type          |   amount_inr | received_date   |
|:-------------|:----------------|:----------------------|-------------:|:----------------|
| PAY0155      | Finance         | Vendor Payment        |       492741 | 2026-09-06      |
| PAY0151      | Legal           | Vendor Payment        |       149496 | 2026-09-08      |
| PAY0268      | Finance         | Expense Reimbursement |       121796 | 2026-11-01      |
| PAY0198      | HR              | Vendor Payment        |       360280 | 2026-11-06      |
| PAY0289      | Marketing       | Vendor Payment        |       788472 | 2026-11-07      |
| PAY0171      | Marketing       | Vendor Payment        |       119220 | 2026-11-09      |

## Q2. GROUP BY: payment count and value by status
*Quick snapshot of the whole workload.*

```sql
SELECT status,
       COUNT(*)                AS payment_count,
       ROUND(SUM(amount_inr),0) AS total_amount_inr
FROM payments
GROUP BY status
ORDER BY payment_count DESC;
```

| status    |   payment_count |   total_amount_inr |
|:----------|----------------:|-------------------:|
| Completed |             271 |        6.67104e+07 |
| Pending   |              13 |        2.18817e+06 |
| Rejected  |               8 |        1.6187e+06  |
| On Hold   |               8 |   965358           |

## Q3. GROUP BY + CASE: SLA compliance % by business unit (completed payments only)
*SLA is met when processed within sla_days of receipt.*

```sql
SELECT business_unit,
       COUNT(*) AS completed,
       SUM(CASE WHEN julianday(processed_date) - julianday(received_date) <= sla_days THEN 1 ELSE 0 END) AS within_sla,
       ROUND(100.0 * SUM(CASE WHEN julianday(processed_date) - julianday(received_date) <= sla_days THEN 1 ELSE 0 END) / COUNT(*), 1) AS sla_pct
FROM payments
WHERE status = 'Completed' AND processed_date IS NOT NULL
GROUP BY business_unit
ORDER BY sla_pct ASC;
```

| business_unit   |   completed |   within_sla |   sla_pct |
|:----------------|------------:|-------------:|----------:|
| Procurement     |          53 |           48 |      90.6 |
| Operations      |          41 |           39 |      95.1 |
| Finance         |          32 |           31 |      96.9 |
| Legal           |          33 |           32 |      97   |
| Marketing       |          34 |           33 |      97.1 |
| HR              |          40 |           40 |     100   |
| Technology      |          37 |           37 |     100   |

## Q4. JOIN: each payment with its approver's name and region
*INNER JOIN between payments and the approvers table.*

```sql
SELECT p.payment_id, p.business_unit, a.approver_name, a.region, p.amount_inr, p.status
FROM payments p
JOIN approvers a ON a.approver_id = p.approver_id
ORDER BY p.amount_inr DESC
LIMIT 10;
```

| payment_id   | business_unit   | approver_name   | region   |   amount_inr | status    |
|:-------------|:----------------|:----------------|:---------|-------------:|:----------|
| PAY0154      | Technology      | Karan Mehta     | West     |       890091 | Completed |
| PAY0121      | Legal           | Suresh Kumar    | North    |       877191 | Completed |
| PAY0185      | Legal           | Suresh Kumar    | North    |       875840 | Completed |
| PAY0192      | HR              | Anita Das       | East     |       867928 | Completed |
| PAY0034      | Procurement     | Vikram Rao      | North    |       855197 | Completed |
| PAY0134      | Procurement     | Vikram Rao      | North    |       843233 | Completed |
| PAY0182      | Operations      | Pooja Gupta     | East     |       837298 | Completed |
| PAY0211      | Procurement     | Vikram Rao      | North    |       821626 | Completed |
| PAY0098      | Procurement     | Vikram Rao      | North    |       808280 | Completed |
| PAY0291      | Finance         | Rohit Sharma    | North    |       802861 | Completed |

## Q5. JOIN + GROUP BY: pending workload per approver
*Shows which approvers' items are waiting, useful for follow-ups.*

```sql
SELECT a.approver_name, a.business_unit,
       COUNT(*)                  AS pending_count,
       ROUND(SUM(p.amount_inr),0) AS pending_value_inr
FROM payments p
JOIN approvers a ON a.approver_id = p.approver_id
WHERE p.status = 'Pending'
GROUP BY a.approver_id, a.approver_name, a.business_unit
ORDER BY pending_count DESC;
```

| approver_name   | business_unit   |   pending_count |   pending_value_inr |
|:----------------|:----------------|----------------:|--------------------:|
| Rohit Sharma    | Finance         |               4 |              642402 |
| Amit Singh      | Marketing       |               3 |              916366 |
| Suresh Kumar    | Legal           |               2 |              170692 |
| Priya Nair      | Marketing       |               1 |                3378 |
| Vikram Rao      | Procurement     |               1 |               81375 |
| Anita Das       | HR              |               1 |              360280 |
| Pooja Gupta     | Operations      |               1 |               13680 |

## Q6. Aging calculation: open payments by aging bucket (as of 10-Nov-2026)
*Aging = days between received_date and the report date. CASE creates the buckets.*

```sql
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
```

| aging_bucket   |   payments |        value_inr |
|:---------------|-----------:|-----------------:|
| 0-1 days       |          2 | 200595           |
| 2-3 days       |          1 | 788472           |
| 4-7 days       |          4 | 512446           |
| 8+ days        |         14 |      1.65202e+06 |

## Q7. SLA breaches: completed payments that took longer than the SLA
*Lists exceptions with the number of days delayed, for root-cause review.*

```sql
SELECT payment_id, business_unit, received_date, processed_date,
       CAST(julianday(processed_date) - julianday(received_date) AS INTEGER) AS days_taken,
       CAST(julianday(processed_date) - julianday(received_date) AS INTEGER) - sla_days AS days_over_sla
FROM payments
WHERE status = 'Completed'
  AND processed_date IS NOT NULL
  AND julianday(processed_date) - julianday(received_date) > sla_days
ORDER BY days_over_sla DESC
LIMIT 10;
```

| payment_id   | business_unit   | received_date   | processed_date   |   days_taken |   days_over_sla |
|:-------------|:----------------|:----------------|:-----------------|-------------:|----------------:|
| PAY0231      | Operations      | 2026-09-09      | 2026-09-14       |            5 |               3 |
| PAY0092      | Operations      | 2026-09-29      | 2026-10-03       |            4 |               2 |
| PAY0047      | Procurement     | 2026-10-09      | 2026-10-12       |            3 |               1 |
| PAY0056      | Procurement     | 2026-10-02      | 2026-10-05       |            3 |               1 |
| PAY0099      | Procurement     | 2026-09-11      | 2026-09-14       |            3 |               1 |
| PAY0118      | Legal           | 2026-09-04      | 2026-09-07       |            3 |               1 |
| PAY0210      | Finance         | 2026-09-17      | 2026-09-20       |            3 |               1 |
| PAY0220      | Marketing       | 2026-09-03      | 2026-09-06       |            3 |               1 |
| PAY0264      | Procurement     | 2026-10-11      | 2026-10-14       |            3 |               1 |
| PAY0276      | Procurement     | 2026-09-02      | 2026-09-05       |            3 |               1 |

## Q8. Monthly trend: volume, value and SLA % by month
*strftime extracts the month for trend reporting.*

```sql
SELECT strftime('%Y-%m', received_date) AS month,
       COUNT(*) AS payments_received,
       ROUND(SUM(amount_inr),0) AS total_value_inr,
       ROUND(100.0 * SUM(CASE WHEN status='Completed' AND julianday(processed_date)-julianday(received_date) <= sla_days THEN 1 ELSE 0 END)
             / NULLIF(SUM(CASE WHEN status='Completed' THEN 1 ELSE 0 END),0), 1) AS sla_pct
FROM payments
GROUP BY month
ORDER BY month;
```

| month   |   payments_received |   total_value_inr |   sla_pct |
|:--------|--------------------:|------------------:|----------:|
| 2026-09 |                 137 |       3.05386e+07 |      94.4 |
| 2026-10 |                 126 |       3.14302e+07 |      96.6 |
| 2026-11 |                  37 |       9.51382e+06 |     100   |

## Q9. HAVING: business units with SLA below 95%
*HAVING filters after grouping, which WHERE cannot do.*

```sql
SELECT business_unit,
       COUNT(*) AS completed,
       ROUND(100.0 * SUM(CASE WHEN julianday(processed_date)-julianday(received_date) <= sla_days THEN 1 ELSE 0 END) / COUNT(*), 1) AS sla_pct
FROM payments
WHERE status = 'Completed' AND processed_date IS NOT NULL
GROUP BY business_unit
HAVING sla_pct < 95
ORDER BY sla_pct;
```

| business_unit   |   completed |   sla_pct |
|:----------------|------------:|----------:|
| Procurement     |          53 |      90.6 |

## Q10. Data validation: records with missing approver or missing processed date
*Supports data integrity checks: finds payments with no approver, and completed payments with no processed date.*

```sql
SELECT payment_id, status, approver_id, processed_date,
       CASE WHEN approver_id IS NULL THEN 'Missing approver'
            WHEN status = 'Completed' AND processed_date IS NULL THEN 'Completed but no processed date'
       END AS issue
FROM payments
WHERE approver_id IS NULL
   OR (status = 'Completed' AND processed_date IS NULL);
```

| payment_id   | status    |   approver_id | processed_date   | issue                           |
|:-------------|:----------|--------------:|:-----------------|:--------------------------------|
| PAY0012      | Completed |           nan | 2026-10-13       | Missing approver                |
| PAY0058      | Completed |           nan | 2026-10-27       | Missing approver                |
| PAY0089      | Completed |             9 | nan              | Completed but no processed date |
