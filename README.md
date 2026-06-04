# Hasbro Analytics Engineer Take-Home

A dbt project against the provided SQLite database that turns intentionally messy synthetic data into a tested, documented gold layer. 32 models, 70 tests, all passing.

I built this to demonstrate a *pattern* — sources, staging, dims, facts, derived marts, data quality models — that scales across domains rather than perfectly resolving every issue in one of them. The same approach would handle a sixth franchise tomorrow: new sources, new staging models, the marts pick up the data automatically.

## How to run

Prereqs: Python 3.9+, git.

```bash
git clone https://github.com/MatuteCorp95/hasbro-analytics-takehome.git
cd hasbro-analytics-takehome
python -m venv .venv
.venv\Scripts\Activate.ps1   # Windows; on Mac/Linux: source .venv/bin/activate
pip install dbt-core dbt-sqlite
```

Set up `~/.dbt/profiles.yml` with the SQLite path (see `profiles.example.yml`), then:

```bash
dbt debug
dbt run
dbt test
dbt docs generate
dbt docs serve
```

I committed the SQLite database in `data/` because the dataset is synthetic and small. In a real project I'd commit a script that builds the database, not the database itself.

## Approach

I chose breadth over depth. The brief asks for judgment, prioritization, modeling approach, and clarity — and the hiring conversation focused on a gold layer that scales across franchises. So I covered all five suggested core dimensions and the major facts (commercial, supply chain, marketing) with a *consistent* standardization and testing pattern. Going deep on one domain at the expense of others wouldn't have shown the scaling thesis.

The single most important architectural choice: staging models stay 1:1 with source rows. Both the PLM and ERP rows for SKU-1001 survive into `stg_products`. The merge logic — PLM-wins for master attributes, ERP-wins for transactional fields, hierarchy-wins for curated standardized values — lives in `dim_product`. That separation keeps lineage auditable. Anyone asking "where did this brand value come from?" can answer it from the dim's `is_in_plm` / `is_in_erp` / `is_in_hierarchy` flags. If I dedup in staging, that audit trail disappears.

## Project structure

- `models/staging/` — 15 standardization models, one per source table. View materialized. No dedup, no FK validation; just type-clean, value-clean, taxonomy-normalized records.
- `models/marts/core/` — five dimensions (product, customer, supplier, warehouse, carrier). Dedup and source-system resolution happen here with deterministic tiebreakers documented per-model.
- `models/marts/commercial/`, `supply_chain/`, `marketing/` — facts with derived business metrics (fill rate, fulfillment status, on-time delivery, weeks of supply, ROAS).
- `models/marts/unified/mart_product_performance` — ties every domain back to product SKU. This is the showcase mart for cross-domain analytics from one consistent key.
- `models/data_quality/` — three DQ models surface what the gold layer didn't silently absorb: orphan FKs, date logic violations, value violations.

## Standardization strategy

The provided `taxonomy_lookup_raw` table has mappings for SKU normalization, channels, regions, countries, platforms, suppliers, statuses, and units of measure. I treat it as canonical reference data — every staging model joins to `stg_taxonomy_lookup` for its relevant mappings.

The source taxonomy is incomplete. During the build I found four real gaps: `sku1007` (the hierarchy table uses a lowercase prefix that the taxonomy doesn't cover), `United States` and `Poland` (country names that don't map to ISO codes), and `Europe` (used interchangeably with `EMEA` in some rows).

The temptation was to hardcode fixes into individual staging models. I forced myself to do something else: extend `stg_taxonomy_lookup` with a `discovered_gaps` block and a `mapping_source` column. Downstream behavior is identical, but `mapping_source='discovered_gap'` makes the workarounds visible to whoever owns the taxonomy long-term. Anyone reading the model knows which mappings need to be promoted upstream and which were built on top.

One honest call here: the `Europe → EMEA` mapping is an assumption. Europe is a continent, EMEA is a business region (Europe + Middle East + Africa). I forced it through because only European countries appear in this dataset. In production I'd verify with regional ops before treating them as equivalents.

## Data quality: fix, flag, quarantine, preserve, or document

The brief asks for judgment in deciding what to fix, flag, or document. I broke it into five categories and applied them consistently:

**Fix silently** — pure type and format issues with no business meaning. Whitespace, case inconsistencies (`'sku1001'` → `'SKU-1001'`), empty strings to NULLs, date format unification (`'01/15/2024'` → `'2024-01-15'`, `'2024/02/05'` → `'2024-02-05'`). These would be auto-fixed in any production load.

**Coerce to NULL with a flag** — non-numeric junk in numeric columns (`'unknown'`, `'thirty five'`, `'not set'`, `'abc'`, `'bad timestamp'`). These get NULLed during casting, the row survives, and downstream models surface the consequence. SO-10006 in `fct_sales_orders` shows `fulfillment_status='units_unknown'` rather than getting silently dropped or misclassified.

**Preserve and flag** — negative inventory, negative POS units (returns), negative marketing clicks. These are real business signals, not data corruption. They survive into facts and light up dedicated flag columns (`has_negative_on_hand_flag`, `is_oversold`, `has_negative_pos_flag`). Analysts choose whether to include or exclude.

**Quarantine, never drop** — orphan foreign keys. SO-10007 references CUST-007 (not in customers), PO-5006 references SUP-404 (not in suppliers), SHP-9006 references SO-99999 (not in orders), CMP-999 has no campaign master record. All survive into the facts with `is_known_*` flags set to 0, and they appear in `dq_orphan_records`. Silently dropping orphans is how analysts lose trust the moment they go back to source.

**Document but don't resolve** — multi-currency. USD, CAD, GBP all appear in money fields. Converting requires an FX rate source we don't have. Every money field keeps its `currency` column; a future enhancement would add `dim_fx_rate` and conformed conversion logic.

**Flag, don't silently resolve** — the overlapping SCD2 ranges on SKU-1001 in `product_hierarchy_raw`. Two records, both effectively current, with overlapping effective dates. In production this would be raised to the data steward. For the dim I take the most recent non-end-dated record and surface the overlap in `dq_date_violations`.

## Key findings

A few real stories surface from the unified mart and the DQ models. The two I'd lead with:

**Ocean Orbit Builder (SKU-1007) — prelaunch with a broken supply chain.** Zero on-hand at WH-002, 900 units in transit, a 300-unit open order from a strategic customer, marketing prelaunch campaign live with $1,100 already spent. Normal prelaunch profile so far. The interesting part: the next-batch PO (PO-5006, 900 units) is open against supplier SUP-404 — which doesn't exist in the supplier master. Somebody approved a 900-unit PO to an unrecognized vendor. Whether it's a typo, a vendor-onboarding gap, or something worse, the unified mart makes it visible in one row. Each system in isolation looks fine. Combined, the problem is obvious.

**Color Cloud Studio (SKU-1004) — stockout with overdue PO.** Current on_hand = 0. The PO that was supposed to replenish (PO-5004, 1,200 units from Delta Plastics, requested April 25, 2024) is still open with zero received — well over a year overdue. Meanwhile $1,500 of marketing continues to drive demand. Classic supply chain failure surfaced in a single mart query.

**Robo River Racer (SKU-1005) — overselling at the main warehouse.** WH-001 inventory snapshot shows on_hand = -25, available = -75. Both `has_negative_on_hand_flag` and `is_oversold` fire. POS data still shows positive sell-through. Either the system is processing orders against negative inventory, or there's a counting error. Either way, supply chain needs to look.

**Garden Quest Card Game (SKU-1006) — discontinued but still selling.** Lifecycle status is discontinued as of January 2024. POS data from CUST-999 shows 10 units still moving in April. Either residual channel inventory liquidating, or the discontinuation was premature. Worth a conversation with brand management. This one is a good example of why sell-in (orders) and sell-through (POS) need to be in the same view — the discrepancy is invisible otherwise.

## Testing

70 tests, all passing. The pattern:

- `not_null` on every primary key and critical FK across staging, dims, facts, marts, and DQ models.
- `unique` on every dim PK (proves dedup worked).
- `relationships` on every fact-to-dim FK, scoped to `is_known_*=1` rows. This is deliberate — without the scoping, the tests would fail on the orphans I deliberately preserved. With it, the test asserts what matters: for every row where I claim the FK is known, that FK really exists in the dim. Orphans are surfaced through DQ models — two different surfaces for two different questions.
- `accepted_values` on every status / enum field and every boolean flag.

I focused on tests that prove the gold-layer thesis — resolved data is integrated, unresolved data is visible — rather than testing every column. A production version would easily double the test count with custom tests on safe-cast nullification, date monotonicity within shipment events, and inventory balance reconciliation.

## Tradeoffs and assumptions

I haven't shipped a dbt project on SQLite before — my prior work has been on Snowflake and BigQuery. So a few patterns here are SQLite-specific translations of what I'd normally reach for:

- `julianday()` for date math instead of `dateadd` / `datediff`. Same result, different syntax.
- `glob` for character-class pattern matching (only place LIKE doesn't help), `like` for everything else.
- A "cast-back-to-text" trick for safe integer parsing instead of `dbt_utils.safe_cast`. SQLite silently casts `'abc'` to 0, and 0 is a legitimate value for fields like `shipped_units`, so the round-trip-and-compare distinguishes real zeros from coerced ones.
- No surrogate keys. Natural keys are sufficient at this scale; in production with hash surrogate keys via `dbt_utils.generate_surrogate_key`, join performance would benefit but the model semantics stay the same.
- No `dbt_utils` dependency. The community SQLite adapter has had compatibility friction with that package, and I didn't want a take-home blocked on adapter issues. On a fully-supported platform I'd absolutely use it.
- No incremental models, no snapshots. Volume doesn't justify either. At Hasbro scale I'd add `materialized='incremental'` with `strategy='merge'` on the high-volume facts (inventory, POS, marketing performance) keyed on natural composite keys, with platform-specific clustering (Z-order on Databricks, cluster keys on Snowflake) on the filter columns. For Type 2 history I'd use `dbt snapshot` on `stg_products` rather than relying on the source's existing-but-broken effective dates.

Other assumptions I made:

- **System-of-record rule for products.** PLM wins for master attributes, ERP wins for transactional fields, hierarchy wins for division and standardized hierarchy. This is the standard CPG pattern. I confirmed it against a few reference sources because I haven't worked directly in CPG; the `is_in_*` flags on `dim_product` keep the resolution auditable per row regardless.
- **Dedup tiebreakers** without an `updated_at` on the source records. I used deterministic proxy rules: shorter country code wins (proxy for ISO format), non-NULL critical fields beat null ones, IANA timezones beat short codes, alphabetical name as final tiebreaker. These are documented per dim. In production I'd push back upstream to add `updated_at` and use latest-wins.
- **Weeks-of-supply uses simple average velocity** across all observed POS weeks. Production would use a trailing 8 or 13 weeks; the dataset has too little history for trailing logic to be meaningful.

## What I'd improve next

In rough order of impact:

- **Move the taxonomy to a versioned dbt seed CSV.** Treating reference data as code is the senior pattern. The discovered_gaps entries would live in the seed, tracked in git, reviewable in PR.
- **Refactor safe-cast logic into shared macros.** Two patterns repeat across most staging models. A `safe_numeric()` macro using the glob letter check would handle both integer and real columns and shorten every staging model by ~30%.
- **Add a `dim_campaign` and a `dim_date`.** Both would simplify the unified mart and enable proper time-series analytics.
- **Currency conversion.** A `dim_fx_rate` with effective dates and conformed conversion logic so `total_marketing_spend` across regions is actually meaningful.
- **`dq_*` models as scheduled tests with alerting** rather than persistent views. They'd write count summaries to a monitoring table on their own schedule, with thresholds routing by domain ownership — orphan FK spikes to data eng, SCD2 overlaps to the data steward, negative inventory to supply chain ops.
- **A daily snapshot `fct_inventory_position_daily`** with carryforward logic, so weeks-of-supply can use trailing windows rather than averaging all history.
- **Custom tests on safe-cast outputs.** The current tests prove enums hold; a custom test (`assert_null_when_non_numeric_in_source`) would prove the coercion was triggered correctly on the right rows.

## A note on process

I built this in two focused sessions across two days, about 13 hours total. I used AI (Claude) as a thinking partner the same way I'd use a senior peer — to challenge decisions, debug SQLite-specific gotchas (the GLOB-vs-LIKE bug being a good example), and pressure-test my framing. The judgment calls — what to fix vs flag, the system-of-record rule, the dedup tiebreakers, what to test, what to surface in DQ — are mine. The code patterns are translations of what I've shipped before on different platforms, adapted to dbt-SQLite.
