# Hasbro Analytics Engineer Take-Home

This is a dbt project built against the provided SQLite database for the Senior Analytics Engineer take-home assessment. It standardizes, tests, and unifies consumer product, commercial, marketing, and supply chain data into an analytics-ready gold layer.

The goal was to demonstrate the *pattern* of building a scalable gold layer rather than perfectly solving every data quality issue in the source. The same approach — sources, staging, dims, facts, derived marts, data quality models — extends cleanly to additional domains without code changes.

## How to run

Prereqs: Python 3.9+, git.

```bash
git clone https://github.com/MatuteCorp95/hasbro-analytics-takehome.git
cd hasbro-analytics-takehome
python -m venv .venv
.venv\Scripts\Activate.ps1   # Windows; use source .venv/bin/activate on Mac/Linux
pip install dbt-core dbt-sqlite
```

Set up `~/.dbt/profiles.yml` with the SQLite path (see `profiles.example.yml` in the repo for the template) and:

```bash
dbt debug
dbt run
dbt test
dbt docs generate
dbt docs serve
```

The SQLite database is committed in `data/` because the dataset is synthetic and small. In a real project the database would be built from a script and not committed.

## Approach

I chose breadth over depth. The brief asks for judgment, prioritization, modeling approach, and clarity — and the hiring conversation focused on a gold layer that scales across multiple franchises. So I covered all five suggested core dimensions and the major facts (commercial, supply chain, marketing) with a *consistent* standardization and testing pattern. The framework would extend cleanly to a sixth domain — just new sources, new staging models, and new mart entries.

The single most important architectural choice was where system-of-record resolution lives. Staging models stay 1:1 with source rows — both the PLM and ERP rows for SKU-1001 survive into `stg_products`. The merge logic (PLM-wins for master attributes, ERP-wins for transactional fields, hierarchy-wins for the curated standardized hierarchy) lives in `dim_product`. That separation keeps lineage auditable: anyone asking "where did this brand value come from?" can answer it from the dim's `is_in_plm` / `is_in_erp` / `is_in_hierarchy` flags.

## Project structure

- `models/staging/` — 15 standardization models, one per source table. View materialized. No deduplication, no FK validation; just type-clean, value-clean, taxonomy-normalized records.
- `models/marts/core/` — five dimensions (product, customer, supplier, warehouse, carrier). Deduplication and source-system resolution happen here with deterministic tiebreakers documented per-model.
- `models/marts/commercial/`, `supply_chain/`, `marketing/` — facts with derived business metrics (fill rate, fulfillment status, on-time delivery, weeks of supply, ROAS, etc.).
- `models/marts/unified/mart_product_performance` — ties every domain back to product SKU. This is the gold-layer mart that demonstrates cross-domain analytics from one consistent key.
- `models/data_quality/` — three DQ models surface what the gold layer didn't silently absorb: orphan FKs, date logic violations, value violations.

## Standardization strategy

The provided `taxonomy_lookup_raw` has mappings for SKU normalization, channels, regions, countries, platforms, suppliers, statuses, and units of measure. I treat it as canonical reference data. Every staging model joins to `stg_taxonomy_lookup` and applies its relevant mappings.

The source taxonomy is incomplete. During the build I found four real gaps: `sku1007` (hierarchy table uses a lowercase prefix), `United States` and `Poland` (country names that don't normalize to the ISO codes), and `Europe` (used interchangeably with `EMEA`). Rather than hardcoding fixes into individual models, I added a `discovered_gaps` block to `stg_taxonomy_lookup` with a `mapping_source` provenance column (`source_taxonomy` vs `discovered_gap`). Downstream behavior is identical, but anyone reading the model can see which mappings came from where — and could remove the discovered_gaps once the source taxonomy is updated by the data governance team.

## Data quality: fix, flag, or quarantine

The brief asks for judgment in deciding what to fix, flag, or document. Here's how I decided:

**Fix silently** — type and format issues with no business semantics: leading whitespace, case inconsistencies (`'sku1001'` → `'SKU-1001'`), empty strings to NULLs, date format unification (`'01/15/2024'` → `'2024-01-15'`, `'2024/02/05'` → `'2024-02-05'`). These would be fixed automatically in any production data load.

**Coerce to NULL with a flag** — non-numeric junk in numeric columns (`'unknown'`, `'thirty five'`, `'not set'`, `'abc'`, `'bad timestamp'`). These get NULLed during casting, and downstream models surface them. `fct_sales_orders` shows SO-10006 with `fulfillment_status = 'units_unknown'` rather than hiding the row.

**Preserve and flag** — negative inventory, negative POS units (returns), negative marketing clicks. These are real business signals, not data corruption. They survive into facts and light up dedicated flag columns (`has_negative_on_hand_flag`, `is_oversold`, `has_negative_pos_flag`, etc.). Analysts choose whether to include or exclude.

**Quarantine, never drop** — orphan foreign keys. SO-10007 references CUST-007 (not in customers), SO-10008 references SKU-8888, PO-5006 references SUP-404, SHP-9006 references SO-99999, CMP-999 has no campaign master record. All survive into facts with `is_known_*` flags set to 0, and they appear in `dq_orphan_records` as a centralized FK violation report. Silently dropping orphan rows is how analysts lose trust in your numbers.

**Document but don't resolve** — multi-currency. USD, CAD, and GBP appear in orders, POs, shipments, and marketing data. Converting requires an FX rate source the data doesn't include. Currency stays on every row as `currency`; a future enhancement adds a `dim_fx_rate` and conformed conversion logic.

**Flag, never silently resolve** — overlapping SCD2 ranges on SKU-1001 in `product_hierarchy_raw`. In production this would be raised to the data steward. For the dim I take the most recent non-end-dated record; the overlap is visible in `dq_date_violations`.

## Key findings

Five stories emerge from `mart_product_performance` and the DQ models:

**Ocean Orbit Builder (SKU-1007) — prelaunch with a broken supply chain.** Zero on-hand at WH-002, 900 units in transit, a 300-unit open customer order, and an open PO (PO-5006) for 900 units from an unknown supplier (SUP-404). Marketing prelaunch campaign is live ($1,100 spend) with zero conversions because purchases aren't possible yet. The unknown supplier is the urgent flag — someone approved a 900-unit PO to a supplier that isn't in supplier master.

**Robo River Racer (SKU-1005) — overselling at the main warehouse.** WH-001 inventory snapshot shows on_hand_qty = -25, available_qty = -75. The fact lights up both `has_negative_on_hand_flag` and `is_oversold`. POS data still shows positive sell-through. Either the system is processing orders against negative inventory, or there's a counting / write-down error. Operations should investigate.

**Color Cloud Studio (SKU-1004) — stockout with an overdue PO.** Current on_hand = 0 (the snapshot field was empty in source), but a Q2 PO from Delta Plastics (PO-5004 for 1,200 units, requested April 25, 2024) never came in. PO status is still "open" with zero received. Meanwhile $1,500 of marketing continues to drive demand the supply chain can't fulfill. Classic supply chain failure that the unified mart surfaces in one row.

**Garden Quest Card Game (SKU-1006) — discontinued but still moving.** Lifecycle = discontinued as of January 2024, but POS data from CUST-999 shows 10 units still selling through in April 2024. Either residual channel inventory liquidating, or the discontinuation was premature. Worth a conversation with brand management.

**The "Broken Campaign" CMP-007 and orphan CMP-999.** CMP-007 has `budget = 'not set'`, no taxonomy code, no region, and references SKU-4040 which doesn't exist. Clearly abandoned during campaign creation but still sitting in the source. CMP-999 in performance has no matching campaign master row — the same problem from the other direction. Both surface in `dq_orphan_records`.

## Testing

70 tests, all passing. Coverage:

- `not_null` on every primary key and critical FK across staging, dims, facts, marts, and DQ models
- `unique` on every dim PK (proves deduplication worked)
- `relationships` on every fact-to-dim FK, scoped to `is_known_*` = 1 rows (proves the gold layer integrates cleanly for resolved FKs while leaving orphans visible via DQ models)
- `accepted_values` on every status / enum field and every boolean flag (proves standardization holds)

The pattern is deliberate. The tests prove the gold-layer thesis — resolved data is integrated and unresolved data is visible — rather than testing every column for the sake of count. Total test count would easily double in a production version with custom tests on safe-cast nullification, date-monotonicity within shipment events, and inventory-balance reconciliation.

## Tradeoffs and assumptions

- **dbt-SQLite, not Snowflake or Databricks.** The take-home uses SQLite so the build runs on `dbt-sqlite`. The model patterns are identical to what would ship on Snowflake; only platform-specific functions (`julianday`, `glob`) would change.
- **No `dbt_utils`.** The community SQLite adapter has had compatibility friction with that package. Natural keys throughout, no surrogate keys via `generate_surrogate_key`. On a fully-supported adapter, surrogate keys would be added and the safe-cast logic below would become macros.
- **Two safe-cast patterns instead of a shared macro.** Integer coercion uses cast-back-to-text comparison (preserves legitimate zeros); real coercion uses a `glob` letter check. In production these would be factored into `safe_int` and `safe_real` macros to shorten every staging model.
- **No incremental models, no snapshots.** Data volume doesn't justify either. The hierarchy table has SCD2-like structure in source; dbt snapshots would be redundant.
- **The product system-of-record rule is opinionated.** PLM wins for master attributes (name, brand, franchise, category, age, lifecycle), ERP wins for transactional fields (unit cost, list price, case pack), hierarchy wins for division and standardized hierarchy fields. This is the standard pattern in CPG and consumer goods. The `is_in_*` flags on `dim_product` make the resolution auditable per row.
- **Weeks-of-supply uses simple average velocity across all observed weeks.** Production would use trailing 8 or 13 weeks. The dataset has too little history for trailing logic to be meaningful.
- **Dedup tiebreakers are deterministic but arbitrary in places.** No source-system `updated_at` is available on `customers_raw` or `warehouse_locations_raw`. The dim tiebreakers (shorter country code wins, IANA timezone wins over short code, non-NULL critical fields win) are defensible but I would push back upstream to add `updated_at` to source extracts.

## What I'd improve next

- **Move the taxonomy to a versioned dbt seed CSV.** Treating reference data as code is the senior pattern. Right now it's a source table extended in the staging model; a seed file would make extensions tracked in git.
- **Add a `dim_campaign` and `dim_date`.** Both simplify the unified mart and enable time-series analytics the current build doesn't support cleanly.
- **Currency conversion.** Add `dim_fx_rate` and conform money fields to USD. Multi-currency aggregates aren't valid today.
- **Refactor safe-cast logic into macros.** Two patterns repeat across most staging models; factoring them would shorten every staging model by ~30%.
- **`dq_*` models as scheduled tests with alerting.** They currently rebuild on every run. In production they'd live on a separate schedule wired to alerting.
- **A daily snapshot `fct_inventory_position_daily`.** The current `fct_inventory_snapshots` is point-in-time at whatever cadence the source delivers. A daily snapshot table with carryforward logic would enable proper days-of-supply trending.
- **Custom tests on the safe-cast output.** The current tests prove enums hold; a custom test (`assert_null_when_non_numeric_in_source`) would prove the coercion was triggered correctly on the right rows.

---

*Built with dbt-core 1.11 + dbt-sqlite 1.10 against the provided synthetic database. Total: 32 models, 70 tests, all passing.*
