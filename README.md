# GA4 Digital Insights: channels, funnel, attribution and testing

An end to end digital insights project on Google's public GA4 export for the Google Merchandise Store (1 November 2020 to 31 January 2021), queried in BigQuery. It answers the questions a digital marketing team asks every month, and includes the tracking plan and test plan that keep those answers trustworthy.

## The questions

| Question | Answered in |
| --- | --- |
| Which channels bring revenue, not just traffic? | [`sql/01_channel_performance.sql`](sql/01_channel_performance.sql) |
| Where do shoppers drop out of the purchase journey, and does it differ by device? | [`sql/02_funnel_dropoff.sql`](sql/02_funnel_dropoff.sql) |
| Which landing pages start good journeys, and which ones underperform the site? | [`sql/03_landing_pages.sql`](sql/03_landing_pages.sql) |
| How much does each channel's credit change between first touch and last click? | [`sql/04_attribution_first_vs_last.sql`](sql/04_attribution_first_vs_last.sql) |
| What should we test next, and how long would it take to prove? | [`sql/05_ab_test_baseline.sql`](sql/05_ab_test_baseline.sql), [`experimentation/`](experimentation/) |
| Can we trust the tracking these answers rely on? | [`tracking/`](tracking/), [`sql/06_utm_audit.sql`](sql/06_utm_audit.sql) |

## Findings

Results from the public sample, with the charts in [`images/`](images/), are written up here from the CSVs in [`results/`](results/).

## What's in the repo

```
sql/                  BigQuery queries on the GA4 export, one business question each
  00_dataset_profile.sql
  01_channel_performance.sql
  02_funnel_dropoff.sql
  03_landing_pages.sql
  04_attribution_first_vs_last.sql
  05_ab_test_baseline.sql
  06_utm_audit.sql
tracking/        How the data gets collected
  tracking_plan.md      GA4 and GTM setup, data layer specs, consent, QA checks, B2B lead handoff
  event_dictionary.csv  Every event, its trigger, parameters and whether it is a key event
  utm_naming_standard.md
experimentation/      How changes get tested
  ab_test_plan.md       Hypothesis, metrics, guardrails, decision rules, readout template
  sample_size.py        Sample size, test length, readout and sample ratio check
scripts/
  make_charts.py        Turns results/ into images/
results/              Query outputs as CSV
images/               Charts
docs/how_to_run.md    Step by step, free BigQuery sandbox
```

## How to run

Everything runs in the free BigQuery sandbox; no billing account is needed. The full steps are in [`docs/how_to_run.md`](docs/how_to_run.md):

1. Open BigQuery, paste each file from `sql/` and run it.
2. Save each result as a CSV in `results/` under the same name.
3. `pip install -r requirements.txt`, then `python scripts/make_charts.py`.
4. Size the test: `python experimentation/sample_size.py plan --baseline <rate> --mde 0.10 --weekly <sessions>`.

## Method notes

* **Session:** `user_pseudo_id` plus `ga_session_id`, the definition GA4 itself uses.
* **Session source and medium:** the first source and medium recorded in the session. GA4 stores them as event parameters; the user's first acquisition source sits in `traffic_source`.
* **Channels:** a simplified version of GA4's default channel group, in one SQL function shared by the channel and attribution queries.
* **Funnel:** closed, so a session counts at a step only if it reached every earlier step. Open funnel counts sit alongside for comparison.
* **Attribution:** first touch (the channel that acquired the user), last click (the purchase session's channel) and last non direct (the most recent non direct session up to the purchase, the logic behind GA4's paid and organic last click).
* **Obfuscation:** Google masks part of the sample, so some sources show as `<Other>` or `(data deleted)`. They are kept as their own rows rather than dropped, so totals still reconcile.
* **Revenue:** `ecommerce.purchase_revenue_in_usd`.

## Applying this to a B2B site

On a lead generation site the outcome happens in the CRM, not on the website. Section 6 of the [tracking plan](tracking/tracking_plan.md) carries the same approach through to qualified leads: one `generate_lead` key event, campaign source written into the CRM record with the lead, validation rules so the source can't go missing, and channel performance judged on qualified leads and revenue instead of form fills. The [test plan](experimentation/ab_test_plan.md) covers how testing changes when traffic is low.

## Tools

BigQuery SQL on the GA4 export schema (`UNNEST`, window functions, temporary functions) · Google Analytics 4 · Google Tag Manager · Python (pandas, SciPy, matplotlib)

## Data

[`bigquery-public-data.ga4_obfuscated_sample_ecommerce`](https://developers.google.com/analytics/bigquery/web-ecommerce-demo-dataset), published by Google through the BigQuery public datasets program.
