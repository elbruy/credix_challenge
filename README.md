# Credix Cost of Risk Engine

## 1. Project Overview & Goal

This project establishes a scalable data pipeline to calculate the **Cost of Risk** (Expected Loss) for the credit portfolio. It transforms raw postgres data into a trusted Mart and a Semantic Layer to answer: _How much money are we expected to lose based on current portfolio performance?_

### Key Metrics Implemented

- **Total Exposure:** Sum of `Face Value` (Outstanding principal).
- **Provision Rate:** Risk percentage assigned to an asset (0% to 100%).
- **Cost of Risk:** `Face Value` \* `Provision Rate`.

## 2. Architecture & Lineage

The project follows a standard Medallion Architecture (Bronze -> Silver -> Gold):

- **Staging (Bronze):** Cleaning, casting, and surrogate key generation.
- **Intermediate (Silver):** Logic isolation.
  - `int_latest_ratings`: Handles the "Many-to-One" relationship of ratings to buyers, isolating the _latest_ valid rating.
- **Facts (Gold):** Business logic application (`fct_credit_risk`).
- **Semantic Layer:** MetricFlow definition (`credit_risk.yml`) for consistent slicing by time and cohort.

## 3. Key Design Decisions & Assumptions

### A. Handling "Time Travel" (Data Quality)

During the discovery phase, I identified a critical data quality issue where assets appeared to be settled _before_ they were created.

- **Impact:** This would skew "Time to Settle" metrics and invalidate risk aging.
- **Resolution:** Validated with stakeholders and utilized the corrected dataset. Added `assert_positive_duration` tests to prevent regression.

### B. The Unrated Buyer Policy

The pipeline currently performs an **INNER JOIN** between Assets and Ratings.

- **Decision:** Buyers without a credit rating are excluded from the Risk Model.
- **Rationale:** We prioritize **auditability** over estimation. Assigning a default risk (e.g., "C") to unknown entities creates hidden risk. These records are flagged in data quality tests rather than silently backfilled.

### C. Dynamic Ratings

Credit risk is not static. The model uses a Window Function (`ROW_NUMBER`) to apply the rating active _at the moment of reporting_, ensuring the Cost of Risk reflects the buyer's current financial health, not their historical status at origination.

## 4. How to Consume

### BI & Analytics

The table `mart_monthly_risk_summary` is pre-aggregated for high-performance dashboards (e.g., Looker Studio), grouped by:

- `risk_month`
- `buyer_state` (Geographic Concentration)
- `current_rating`

### Semantic Layer (dbt sl)

For ad-hoc exploration, use the Semantic Layer to slice metrics without writing SQL:

```bash
dbt sl query --metrics total_loss --group-by buyer_state,risk_month

## 5. Future Roadmap (Production Readiness)
If moving this to production, the following steps would be prioritized:

### Orchestration
Move from dbt Cloud scheduler to Airflow/Dagster to handle dependencies between ingestion (Postgres -> BQ) and transformation.

### Incremental Models
Convert fct_credit_risk to incremental strategy merge to optimize BigQuery costs as the portfolio scales to millions of rows.

### Data Contracts
Implement contracts at the ingestion source to prevent schema drift (e.g., face_value changing from Numeric to String).
```
