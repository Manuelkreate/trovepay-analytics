# TrovePay Analytics
 
A governed analytics layer for TrovePay, a fictional Nigerian fintech that started as a POS and merchant-acquiring business and expanded into SME lending. The project connects merchant onboarding, transactions, lending and repayment so the business can consistently identify credit-ready merchants and analyse lending outcomes.
 
This is not a credit-scoring or loan-approval model. It defines and tracks readiness and outcomes. It does not predict them.
 
Built with DuckDB and dbt Core. The source data is synthetic and was produced by a separate generator project.
 
## Questions the models answer
 
- Which merchants are active, and which show sustained activity?
- Which merchants are credit-ready today, and how does that population change over time?
- How do lending and repayment outcomes vary by disbursement cohort and business type?
## Data
 
| Table | Rows |
|---|---|
| merchants | 50,000 |
| transactions | 25,302,849 |
| loans | 30,781 |
| repayment schedule | 141,272 (installments due on or before the as-of date) |
| repayments | 114,715 |
 
Window: 1 Jul 2024 to 30 Jun 2026. Transactions end on 31 May 2026. Repayments run to 30 Jun 2026.
 
## Headline results
 
These figures come from synthetic data, so they describe how the generator behaves and not any real lending book. They show what the marts report.
 
- 30,781 loans, of which 19,396 are matured (complete schedule in the data).
- 4,428 matured loans (22.8%) were fully repaid, and 79.3% of the scheduled amount on matured loans was collected. The gap between the two means many loans were partly repaid and not cleared.
- Across all loans, 98% have had at least one late installment, 76% have been more than 30 days late at some point, and 59% are delinquent at the cutoff.
- Fully repaid rates for the earliest disbursement cohorts (July to November 2024) sit between 17% and 23%.
## Lineage
 
```
raw (DuckDB, loaded by scripts/load_raw.py)
  -> staging (7 stg_ models: types and renames only)
  -> intermediate
       int_qualifying_transactions
         -> int_merchant_activity_daily
              -> int_qualifying_activity   (90-day count, value, CV, trend)
              -> int_merchant_recency
                   -> int_credit_readiness
       int_repayment_allocation -> int_loan_outcomes
       int_data_cutoff, int_merchant_observations
  -> marts
       mart_credit_readiness_monthly
       mart_credit_readiness_current
       mart_loan_performance
       mart_loan_performance_by_cohort
```
 
Staging models are views, except `stg_transactions`, which is incremental on `transaction_id`. Intermediate models and marts are tables.
 
## Key definitions
 
- **Qualifying transaction:** status is successful and not reversed as of the observation date. A later reversal never rewrites an earlier snapshot.
- **Observation grid:** one row per merchant per month-end, from onboarding to the data cutoff.
- **Activity window:** trailing 90 days. Frequency is a count, monetary is a value, and recency is days since the last qualifying activity, using full history.
- **Credit-ready:** 90-day count and value at or above fixed thresholds, with activity in the last 45 days. `rolling_ready_state` is re-evaluated at every snapshot. `first_ready_date` is the earliest snapshot where the merchant was ready.
- **Late:** an installment paid after its due date, or still unpaid past it. **Delinquent:** more than 30 days late. Installments due on the cutoff day itself are classed as not yet due.
- **Fully repaid:** the loan's schedule is complete in the data and actual repayments meet the total scheduled obligation.
- **Matured loan:** every scheduled installment is present in the data.
- **Repayment ratio and collection rate:** total repaid divided by total scheduled, per loan and per cohort. Cohort collection rate is calculated on matured loans only. It is reported next to the fully repaid rate because the two answer different questions: how many loans cleared completely, and how much of the scheduled money came back.
## Design decisions
 
**DuckDB over BigQuery.** BigQuery would have needed a GCS prepayment, and the Sandbox has no GCS access, disables DML and MERGE, and expires tables after 60 days. DuckDB runs locally and supports the full workflow.
 
**Pre-aggregating to a daily grain.** Joining month-end snapshots straight to 25M transactions with a range join ran for over 10 minutes. Aggregating to merchant and day first (`int_merchant_activity_daily`) brought the windowed model down to about 16 seconds.
 
**A fixed readiness bar.** The count and value thresholds are the median 90-day count (89) and value (680,524.61) among active merchants at one calibration snapshot, held constant across all rows. A bar that moves with each snapshot's median keeps the ready share roughly constant by construction, so it could never show the ready population growing or shrinking. It also matches how real eligibility rules work, which are absolute. The calibration date and the 45-day recency cutoff are project-level policy values, not derived from the data.
 
**Readiness logic lives in dbt.** Thresholds are not in the BI layer, so every consumer sees the same definition.
 
**Derived cutoff.** `int_data_cutoff` takes the latest date across transactions and repayments, so new data does not require editing a date.
 
**Repayment allocation.** Repayments exist at loan level only. They are allocated to installments oldest-due-first using running totals, with overpayments and post-maturity payments kept.
 
**Maturity from the data, not a date.** The loader applies the as-of date to every table, so the schedule only contains installments due on or before that date. Loans whose final installment is missing are treated as not yet matured, and repayment rates are calculated on matured loans only.
 
**Loader compares at day grain.** An earlier version of `load_raw.py` compared timestamp columns with a date string, which DuckDB reads as midnight. Rows on the cutoff day that carried a time of day were dropped, which dropped 637 installments and left 70 loans maturing on the cutoff date with a missing final installment. Both bounds of the incremental filter now compare on the date, so the cutoff day is loaded in full and the watermark never re-loads it. The issue surfaced as a failing not-null test on a mart, and was traced back through row counts at each layer.
 
## Known limitations
 
- Reversal approximation in `int_merchant_activity_daily`: it filters reversals with a one-day lag instead of the exact observation date. A transaction reversed within a day of a snapshot can be misclassified at that snapshot. The effect should be small and sits at snapshot edges.
- `first_ready_date` is a merchant-level attribute. Early snapshots show a date in their future, which suits lifecycle analysis but not strict as-of analysis.
- The earliest snapshots have partial 90-day windows, so ready counts before January 2025 are understated.
- The latest snapshot is 31 May 2026 because transactions end there.
- The schedule only holds installments due on or before the as-of date, so loans still in term have incomplete schedules. `outstanding_due_amount` is the unpaid amount among installments already due, not the remaining obligation, and `is_fully_repaid` is only meaningful for matured loans.
- A loan maturing on the cutoff day counts as matured, and as not fully repaid if its final installment, which is due that day, is still unpaid. This affects at most about 70 loans.
- The readiness bar comes from synthetic data and would be recalibrated on real data.
- Not built yet: pre-disbursement activity link for loans, and the Airflow DAG.
## Testing
 
93 data tests cover keys, grain (via `dbt_utils.unique_combination_of_columns`), accepted values, relationships and consistency rules, for example that a currently delinquent loan must also be ever delinquent. A singular test fails if the readiness thresholds produce no ready merchants.
 
## Running it
 
Requirements: Python, `duckdb`, `dbt-duckdb`, dbt Core 1.12, `python-dotenv`.
 
1. Create `.env` in the repo root with `GENERATOR_DATA_PATH` pointing at the generated data (use forward slashes or single quotes).
2. Load raw data. `load_raw.py` takes an as-of date. Run it in order for 2024-12-31, 2025-06-30, 2025-12-31 and 2026-06-30. The final transaction count should be 25,302,849.
3. Add a `~/.dbt/profiles.yml` profile named `trovepay_analytics`, type duckdb, with an absolute path to `trovepay.duckdb`.
4. Activate the virtual environment, then from the inner `trovepay_analytics/` folder run:
```
dbt deps
dbt build
```
 
DuckDB allows one process on the database file at a time, so close other connections before running dbt.
 
## Repo layout
 
```
trovepay-analytics/
  scripts/load_raw.py
  trovepay_analytics/     dbt project
    models/staging
    models/intermediate
    models/marts
    tests
```
 
