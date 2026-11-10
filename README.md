# Payment SLA & Aging Analysis (SQL)

A practice project that uses SQL to analyse payment turnaround, SLA compliance and aging, based on the kind of tracker data used in payment operations.

> **Note:** All data is **sample/dummy data** created for practice. It contains no real company, vendor or employee information.

## Dataset

| Table | Description |
|---|---|
| `payments` | 300 sample payment records: business unit, payment type, amount, received date, processed date, status, SLA target (2 days) |
| `approvers` | 10 sample approvers with business unit and region |

## Skills demonstrated

- `SELECT`, `WHERE`, `ORDER BY`
- `GROUP BY` and `HAVING`
- `JOIN` between payments and approvers
- `CASE` statements for SLA flags and aging buckets
- Date calculations (`julianday`, `strftime`)
- Data validation queries (missing approvers, missing processed dates)

## Queries (see `payment_queries.sql`)

1. High-value pending payments
2. Payment count and value by status
3. SLA compliance % by business unit
4. Payments joined with approver details
5. Pending workload per approver
6. Aging buckets for open payments (0-1, 2-3, 4-7, 8+ days)
7. SLA breach list with days over SLA
8. Monthly volume and SLA trend
9. Business units below 95% SLA
10. Data quality checks

## Sample findings

- Overall SLA compliance on completed payments is about 96%.
- Procurement has the lowest SLA (90.6%), followed by Operations (95.1%).
- The validation query finds 3 records with missing approver or processed-date data.

## How to run

1. Install [DB Browser for SQLite](https://sqlitebrowser.org/) (free).
2. Open `payments.db`.
3. Go to the **Execute SQL** tab, paste any query from `payment_queries.sql` and run it.

`query_results.md` shows each query with its output.

## Files

- `payment_queries.sql`: all 10 queries with comments
- `payments.db`: SQLite database
- `payments.csv`, `approvers.csv`: raw data
- `query_results.md`: queries with sample results

## Tools

SQL (SQLite), DB Browser for SQLite
