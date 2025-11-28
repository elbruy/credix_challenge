# Credix Cost of Risk Engine

## 1. Project Overview & Goal

This project establishes a scalable, trusted data pipeline to calculate the **Cost of Risk** (Expected Loss) for the credit portfolio. It transforms raw Postgres data into a "Gold" Mart and a Semantic Layer to answer the critical business question: _How much money are we expected to lose based on current portfolio performance?_

### Key Metrics Implemented

- **Total Exposure:** Sum of `Face Value` (Outstanding principal).
- **Provision Rate:** Risk percentage assigned to an asset (0% to 100%).
- **Cost of Risk:** `Face Value` \* `Provision Rate`.

---

## 2. Architecture & Lineage

The project follows a standard Medallion Architecture (Bronze -> Silver -> Gold) using **dbt Core** and **BigQuery**.

![Lineage Graph](<img width="2816" height="1536" alt="image" src="https://github.com/user-attachments/assets/9b657e45-10d2-435d-8906-2e68a11b12a6" />)

- **Staging (Bronze):** Cleaning, casting, and "Ultimate Surrogate Key" generation.
- **Intermediate (Silver):** Logic isolation.
  - `int_latest_ratings`: Handles the "Many-to-One" relationship of ratings to buyers, isolating the _latest_ valid rating.
- **Facts (Gold):** Business logic application (`fct_credit_risk`) and aggregations (`mart_monthly_risk_summary`).
- **Semantic Layer:** MetricFlow definition (`credit_risk.yml`) for consistent slicing by time and cohort.

---

## 3. Data Engineering Challenges & Solutions

During the development phase, we resolved three critical data quality issues to ensure the engine is "Production-Hardened."

### A. The "Ghost Loan" Artifacts

- **Issue:** The raw dataset contained ~450+ records with `face_value = 0.00`.
- **Diagnosis:** These were technical artifacts/logs rather than valid financial liabilities.
- **Solution:** Implemented a strict filter in `stg_assets` to exclude zero-value records, preventing the artificial inflation of "Loan Count" metrics.

### B. Versioning vs. Duplication

- **Issue:** The source system logs multiple rows for the "same" loan when attributes change (e.g., a renegotiated Due Date). Standard hashing caused key collisions.
- **Solution:** Implemented an "Ultimate Surrogate Key" that hashes **all** business attributes (`State`, `Settlement`, `Due Date`, `Status`). This preserves contractual history (versioning) without breaking uniqueness tests.

### C. The "Implicit Default" Logic Gap

- **Issue:** Some loans were marked `Active` in the source despite being >30 days overdue.
- **Solution:** Implemented a "Business Logic Override" in `fct_credit_risk`.
  - _Rule:_ If `days_overdue > 30`, the status is forced to `Defaulted` (100% Provision).
  - _Impact:_ Caught 322 instances of under-provisioned risk.

---

## 4. 🔍 Business User Guide: Slicing the Metrics

This data model is designed to be "drag-and-drop" ready in tools like Tableau, Looker, or Metabase. Here is how to map business questions to the available dimensions:

| **To Analyze...**       | **Use Field...**   | **Description & Usage**                                                                                                                               |
| :---------------------- | :----------------- | :---------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Time / Trend**        | `risk_month`       | Derived from **Due Date**. Use this to visualize when risk is expected to materialize (e.g., "Show me Expected Loss for October vs. November").       |
| **Segment (Geography)** | `buyer_state`      | The specific Brazilian state code (e.g., SP, RJ). Use this for map visualizations or regional risk concentration analysis.                            |
| **Risk Profile**        | `current_rating`   | The credit rating (A-F) at the time of reporting. Use this to filter out low-risk assets or focus on high-risk exposure.                              |
| **Cohort (Vintage)**    | `asset_id` (Count) | While the primary aggregation is by Risk Month, you can drill down into individual assets in the Fact table to see `created_at` for vintage analysis. |

**Example BI Configuration (e.g., Tableau):**

1.  **Rows:** Drag `buyer_state`.
2.  **Columns:** Drag `risk_month`.
3.  **Values:** Drag `total_expected_loss`.

- _Result:_ A heatmap showing where and when we expect the highest losses.

---

## 5. The Semantic Layer (MetricFlow)

A time spine (`metricflow_time_spine`) was registered to allow for continuous time-series analysis (filling gaps for months with zero activity).

**Entities:**

- `asset_id` (Primary)
- `buyer_tax_id` (Foreign)

**Metrics:**

- `total_exposure`: Sum of Face Value.
- `total_loss`: Sum of Cost of Risk.
- `portfolio_provision_rate`: Ratio of `total_loss` / `total_exposure`.

### Ad-Hoc Query Example

```
dbt sl query --metrics total_loss --group-by buyer_state
```

## 6. How to Run

Install Dependencies:

```
dbt deps
```

Build the Project:

```
dbt build --full-refresh
```

Note: Full refresh is recommended to regenerate the unique surrogate keys.

## 7. Assumptions

**Unrated Policy**: Buyers without a match in the ratings table are currently excluded (Inner Join) to prioritize auditability over estimation.

**Versioning**: If a loan's Due Date changes, it is treated as a separate ledger entry for the purpose of historical risk analysis.

**Source Data**: We assume the database name is credix-challenge. For production, this should be parameterized via \_sources.yml.
