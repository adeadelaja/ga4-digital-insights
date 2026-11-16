# A/B test plan: cart to checkout

## Why this test

The funnel query (`sql/02_funnel_dropoff.sql`) shows where sessions leave the purchase journey. This plan targets the cart step: shoppers have already chosen a product, so every session lost between cart and checkout is close to revenue. The sizing below uses the cart baseline measured in `sql/05_ab_test_baseline.sql`. If the funnel shows the product page step losing far more sessions, the same plan runs on that step instead, with view to cart as the primary metric.

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

Run the planner with the Overall row of `results/05_ab_test_baseline.csv`:

```
python experimentation/sample_size.py plan --baseline <cart_to_checkout_rate> --mde 0.10 --weekly <sessions_added_to_cart>
```

The sized numbers are added to the README once the queries have run on the public sample.

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
