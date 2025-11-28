# Credix Cost of Risk Engine

## 1. Project Overview & Goal

This project establishes a scalable data pipeline to calculate the **Cost of Risk** (Expected Loss) for the credit portfolio. It transforms raw Postgres data into a trusted Mart and a Semantic Layer to answer: _How much money are we expected to lose based on current portfolio performance?_

### Key Metrics Implemented

- **Total Exposure:** Sum of `Face Value` (Outstanding principal).
- **Provision Rate:** Risk percentage assigned to an asset (0% to 100%).
- **Cost of Risk:** `Face Value` \* `Provision Rate`.

## 2. Architecture & Lineage

The project follows a standard Medallion Architecture (Bronze -> Silver -> Gold) using **dbt Core** and **BigQuery**:

- **Staging (Bronze):** Cleaning, casting, and surrogate key generation.
- **Intermediate (Silver):** Logic isolation.
  - `int_latest_ratings`: Handles the "Many-to-One" relationship of ratings to buyers, isolating the _latest_ valid rating using window functions.
- **Facts (Gold):** Business logic application (`fct_credit_risk`).
- **Semantic Layer:** MetricFlow definition (`credit_risk.yml`) for consistent slicing by time and cohort.

## 3. Data Engineering Challenges & Solutions

During the development phase, we encountered and resolved three critical data quality issues.

### A. The "Ghost Loan" Artifacts

- **Issue:** The raw dataset contained ~450+ records with `face_value = 0.00` and status `Settled`.
- **Diagnosis:** These appeared to be technical artifacts or system logs rather than valid financial liabilities.
- **Solution:** Implemented a strict filter in `stg_assets` to exclude zero-value records, preventing the artificial inflation of the "Loan Count" metric (which would have skewed average ticket size analysis).

### B. Versioning vs. Duplication

- **Issue:** The system logs multiple rows for the "same" loan when attributes change (e.g., a **Due Date** renegotiation or a **Settlement Date** update). Standard `SELECT DISTINCT` failed to deduplicate these because the rows were not identical.
- **Decision:** Instead of arbitrarily picking one row, we treated these as **Distinct Asset Versions**.
- **Solution:** Implemented an "Ultimate Surrogate Key" in `stg_assets` that hashes **all** business attributes (`State`, `Settlement`, `Due Date`, `Status`).
  - _Result:_ A Due Date extension is treated as a new liability version, ensuring full traceability of contractual changes without dropping data.

### C. The "Implicit Default" Logic Gap

- **Issue:** Some loans were marked as `Active` in the source system despite being >30 days overdue.
- **Impact:** Calculating Provision Rate based solely on the raw status resulted in dangerous under-provisioning (assigning 5% risk to what should be 100% risk).
- **Solution:** Implemented a "Business Logic Override" in `fct_credit_risk`.
  - _Logic:_ If `days_overdue > 30`, the status is forced to `Defaulted` (100% Provision), regardless of the raw system label.

## 4. The Semantic Layer (MetricFlow)

This project leverages the modern dbt Semantic Layer. A time spine (`metricflow_time_spine`) was registered to allow for continuous time-series analysis.

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

## 5. How to Run

Install Dependencies:

```
dbt deps
```

Build the Project:

```
dbt build --full-refresh
```

Note: Full refresh is recommended to regenerate the unique surrogate keys.

## 6. Assumptions

**Unrated Policy**: Buyers without a match in the ratings table are currently excluded (Inner Join) to prioritize auditability over estimation.

**Versioning**: If a loan's Due Date changes, it is treated as a separate ledger entry for the purpose of historical risk analysis.
