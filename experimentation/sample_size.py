"""
Sample size, duration and readout for a two variant conversion test.

Plan a test from a baseline you measured (sql/05_ab_test_baseline.sql):
    python experimentation/sample_size.py plan --baseline 0.30 --mde 0.10 --weekly 4000

Read out a finished test:
    python experimentation/sample_size.py readout --control 1200 4000 --variant 1290 4000

Check the traffic split before trusting a result (sample ratio mismatch):
    python experimentation/sample_size.py srm --control_n 4000 --variant_n 4100
"""

import argparse
import math

from scipy.stats import chi2, norm


def sample_size_per_variant(baseline, mde_relative, alpha=0.05, power=0.80):
    """Sessions needed in EACH variant for a two sided test of two proportions."""
    p1 = baseline
    p2 = baseline * (1 + mde_relative)
    if not 0 < p1 < 1 or not 0 < p2 < 1:
        raise ValueError("baseline and baseline x (1 + mde) must both sit between 0 and 1")
    z_alpha = norm.ppf(1 - alpha / 2)
    z_beta = norm.ppf(power)
    p_bar = (p1 + p2) / 2
    numerator = (z_alpha * math.sqrt(2 * p_bar * (1 - p_bar))
                 + z_beta * math.sqrt(p1 * (1 - p1) + p2 * (1 - p2))) ** 2
    return math.ceil(numerator / (p2 - p1) ** 2)


def weeks_needed(n_per_variant, weekly_eligible, variants=2, minimum_weeks=2):
    """Whole weeks to run, never fewer than two so every weekday is covered twice."""
    raw = (n_per_variant * variants) / weekly_eligible
    return max(minimum_weeks, math.ceil(raw))


def readout(conv_a, n_a, conv_b, n_b, alpha=0.05):
    """Two proportion z test with a confidence interval for the absolute difference."""
    p_a, p_b = conv_a / n_a, conv_b / n_b
    pooled = (conv_a + conv_b) / (n_a + n_b)
    se_pooled = math.sqrt(pooled * (1 - pooled) * (1 / n_a + 1 / n_b))
    z = (p_b - p_a) / se_pooled
    p_value = 2 * (1 - norm.cdf(abs(z)))
    se_diff = math.sqrt(p_a * (1 - p_a) / n_a + p_b * (1 - p_b) / n_b)
    margin = norm.ppf(1 - alpha / 2) * se_diff
    diff = p_b - p_a
    return {
        "control_rate": p_a,
        "variant_rate": p_b,
        "absolute_lift": diff,
        "relative_lift": diff / p_a if p_a else float("nan"),
        "ci_low": diff - margin,
        "ci_high": diff + margin,
        "z": z,
        "p_value": p_value,
        "significant": p_value < alpha,
    }


def srm_check(n_a, n_b, expected_split=0.5, threshold=0.001):
    """Chi square test that the traffic split matches the plan. A failure means the result can't be trusted."""
    total = n_a + n_b
    expected_a, expected_b = total * expected_split, total * (1 - expected_split)
    stat = (n_a - expected_a) ** 2 / expected_a + (n_b - expected_b) ** 2 / expected_b
    p_value = 1 - chi2.cdf(stat, df=1)
    return {"chi_square": stat, "p_value": p_value, "srm_detected": p_value < threshold}


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)

    plan = sub.add_parser("plan", help="sample size and duration")
    plan.add_argument("--baseline", type=float, required=True, help="baseline conversion rate, e.g. 0.30")
    plan.add_argument("--mde", type=float, required=True, help="smallest relative lift worth detecting, e.g. 0.10 for 10%%")
    plan.add_argument("--weekly", type=int, required=True, help="eligible sessions per week (both variants together)")
    plan.add_argument("--alpha", type=float, default=0.05)
    plan.add_argument("--power", type=float, default=0.80)

    ro = sub.add_parser("readout", help="analyse a finished test")
    ro.add_argument("--control", type=int, nargs=2, metavar=("CONVERSIONS", "SESSIONS"), required=True)
    ro.add_argument("--variant", type=int, nargs=2, metavar=("CONVERSIONS", "SESSIONS"), required=True)
    ro.add_argument("--alpha", type=float, default=0.05)

    srm = sub.add_parser("srm", help="sample ratio mismatch check")
    srm.add_argument("--control_n", type=int, required=True)
    srm.add_argument("--variant_n", type=int, required=True)

    args = parser.parse_args()

    if args.command == "plan":
        n = sample_size_per_variant(args.baseline, args.mde, args.alpha, args.power)
        weeks = weeks_needed(n, args.weekly)
        target = args.baseline * (1 + args.mde)
        print(f"Baseline rate:            {args.baseline:.2%}")
        print(f"Detectable variant rate:  {target:.2%} ({args.mde:.0%} relative lift)")
        print(f"Alpha / power:            {args.alpha} / {args.power}")
        print(f"Sessions per variant:     {n:,}")
        print(f"Sessions in total:        {2 * n:,}")
        print(f"Eligible sessions a week: {args.weekly:,}")
        print(f"Run for:                  {weeks} full weeks")
    elif args.command == "readout":
        r = readout(*args.control, *args.variant, alpha=args.alpha)
        print(f"Control rate:   {r['control_rate']:.2%}")
        print(f"Variant rate:   {r['variant_rate']:.2%}")
        print(f"Absolute lift:  {r['absolute_lift']:+.2%} (95% CI {r['ci_low']:+.2%} to {r['ci_high']:+.2%})")
        print(f"Relative lift:  {r['relative_lift']:+.1%}")
        print(f"p value:        {r['p_value']:.4f} -> {'significant' if r['significant'] else 'not significant'}")
    elif args.command == "srm":
        r = srm_check(args.control_n, args.variant_n)
        print(f"Chi square {r['chi_square']:.2f}, p value {r['p_value']:.5f}: "
              f"{'SAMPLE RATIO MISMATCH, do not trust the result' if r['srm_detected'] else 'split looks healthy'}")


if __name__ == "__main__":
    main()
