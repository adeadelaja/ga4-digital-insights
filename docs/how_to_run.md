# How to run

About 20 minutes from a standing start. Everything is free.

## 1. Open BigQuery

1. Go to [console.cloud.google.com/bigquery](https://console.cloud.google.com/bigquery) and sign in with any Google account.
2. If you are asked to create a project, create one (any name). The BigQuery sandbox needs no card, and these queries sit well inside the free monthly query allowance.

## 2. Run the queries

For each file in `sql/`, in order from `00` to `06`:

1. Click **+** to open a new query tab.
2. Paste the whole file, including the `CREATE TEMP FUNCTION` block where there is one.
3. Before running, check the message in the top right that says how much data the query will process.
4. Click **Run**.
5. Click **Save results**, choose **CSV (local file)**, and save it in `results/` with the same name as the query (for example `results/01_channel_performance.csv`).

## 3. Draw the charts

```
pip install -r requirements.txt
python scripts/make_charts.py
```

The charts appear in `images/`.

## 4. Size the A/B test

Open `results/05_ab_test_baseline.csv`. Leave out any weeks where `sessions_added_to_cart` is zero or clearly partial (the first three in this sample), then take the rate and the weekly average from the rest:

```
python experimentation/sample_size.py plan --baseline <cart_to_checkout_rate> --mde 0.10 --weekly <sessions_added_to_cart>
```

## 5. Check before you publish

* `00_dataset_profile.csv` should show 92 days, 1 November 2020 to 31 January 2021.
* Revenue in `01_channel_performance.csv` should add up to the revenue in `00_dataset_profile.csv`.
* The `All devices` row of step 7 in `02_funnel_dropoff.csv` is lower than the converting sessions in `01` (2,848 against 4,848), because the closed funnel only counts sessions that passed every step. The `sessions_open` column should match `01`.
