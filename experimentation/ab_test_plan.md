# A/B test plan: cart to checkout

## Why this test

The funnel query (`sql/02_funnel_dropoff.sql`) shows where sessions leave the purchase journey. Of sessions that add to cart, 61% never begin checkout (9,214 sessions over three months), the largest loss after the product page. Shoppers at this step have already chosen a product, so every session recovered is close to revenue. The product page step loses more sessions in absolute terms, but its tracking was incomplete for part of the sample, so it is the second test, not the first.

## Hypothesis

If we show the delivery cost and the expected delivery date in the cart, before checkout starts, then more cart sessions will begin checkout, because costs that only appear at checkout are a common reason shoppers abandon.

## Design

| Item | Decision |
| --- | --- |
| Variants | Control: current cart. Variant: cart with delivery cost and delivery date shown under the subtotal |
| Split | 50 / 50 |
| Unit of randomisation | User (cookie), so a returning shopper always sees the same cart |
| Who is in the test | Sessions that reach the cart (`view_cart` or `add_to_cart`) |
| Primary metric | Cart to checkout rate: sessions that begin checkout / sessions that add to cart |
| Secondary metrics | Purchase rate of cart sessions; revenue per cart session |
| Guardrail metrics | Average order value; `remove_from_cart` rate; page load time on the cart; sample ratio mismatch |
| Significance and power | Two sided, alpha 0.05, power 0.80 |
| Smallest lift worth detecting | 10% relative. Smaller lifts would not repay the build and design time, and would need a much longer test |
| Minimum length | Two full weeks, so every weekday appears at least twice |

## Sample size and duration

Baselines from `results/05_ab_test_baseline.csv`, using the ten weeks from 23 November 2020 onwards. The first three weeks are excluded because `add_to_cart` was not being collected (two weeks with no events, one partial).

| Input | Value |
| --- | --- |
| Baseline cart to checkout rate | 39% (38.9% measured) |
| Smallest lift worth detecting | 10% relative, so 39% to 42.9% |
| Cart sessions a week | 1,466 |
| Sessions needed per variant | 2,495 |
| Sessions needed in total | 4,990 |
| Test length | 4 full weeks |

```
python experimentation/sample_size.py plan --baseline 0.39 --mde 0.10 --weekly 1466
```

**Seasonality.** The weekly rate ranged from 24% to 47% across the sample, highest in early December and lowest in the first week of January. The test should run in four ordinary trading weeks and not straddle a seasonal peak, or the week to week swing will be larger than the lift being measured.

**What a win is worth.** At 1,466 cart sessions a week, a 10% lift (3.9 percentage points) would add roughly 740 checkout sessions a quarter. If 48% of them go on to buy, as checkout sessions do today, that is about 355 more orders, or around $26,000 a quarter at $75 per converting session. This is an estimate to judge whether the test is worth running, not a forecast.

## Tracking before launch

1. Push the variant into the data layer on every cart page view: `experiment_id: "cart_delivery_info"`, `experiment_variant: "control"` or `"variant"`.
2. Send both as event parameters on `view_cart`, `begin_checkout` and `purchase`, and register them as custom dimensions in GA4.
3. Check both variants in GTM Preview and GA4 DebugView: every funnel event fires once, with the variant attached.
4. In BigQuery, confirm the variant parameter is present on at least 99% of cart events before reading any result.

## Rules for reading the result

1. **No peeking.** The decision is made once, at the planned sample size. Stopping on a good day inflates false wins.
2. **Check the split first.** Run `python experimentation/sample_size.py srm --control_n <n> --variant_n <n>`. A sample ratio mismatch means something broke in delivery or tracking, so the result is not read.
3. **Ship** if the 95% confidence interval for the primary metric sits above zero and no guardrail is harmed (average order value down by no more than 2%).
4. **Iterate** if the result is flat: the idea may be right and the execution too subtle.
5. **Roll back** if the primary metric falls.
6. Device and new versus returning splits are read for learning, never to rescue a losing test.

## Readout template

| | Control | Variant |
| --- | --- | --- |
| Cart sessions | | |
| Sessions that began checkout | | |
| Cart to checkout rate | | |
| Absolute lift (95% CI) | | |
| p value | | |
| Average order value | | |
| Sample ratio check | | |
| Decision and next test | | |

Fill it with `python experimentation/sample_size.py readout --control <conversions> <sessions> --variant <conversions> <sessions>`.

## On a B2B site

Lead generation sites have far less traffic than a shop, so the same method changes in three ways: test bolder changes so the expected lift is larger, accept a larger smallest detectable lift, and judge the winner on lead quality in the CRM (qualified leads, not form fills) once enough leads have been worked.
