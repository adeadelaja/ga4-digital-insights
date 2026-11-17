"""
Turn the query results in results/ into the charts in images/.

    python scripts/make_charts.py

Each chart is drawn only if its CSV exists, so you can run it after any subset of queries.
"""

from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
RESULTS = ROOT / "results"
IMAGES = ROOT / "images"
IMAGES.mkdir(exist_ok=True)

SURFACE = "#fcfcfb"
INK = "#0b0b0b"
INK_2 = "#52514e"
GRID = "#e4e3df"
SERIES = ["#2a78d6", "#eb6834", "#1baf7a"]  # categorical slots 1 to 3, validated as a set

plt.rcParams.update({
    "figure.facecolor": SURFACE,
    "axes.facecolor": SURFACE,
    "axes.edgecolor": GRID,
    "axes.labelcolor": INK_2,
    "xtick.color": INK_2,
    "ytick.color": INK,
    "font.size": 10,
    "axes.spines.top": False,
    "axes.spines.right": False,
    "axes.spines.left": False,
    "axes.grid": True,
    "axes.grid.axis": "x",
    "grid.color": GRID,
    "grid.linewidth": 0.8,
    "axes.axisbelow": True,
})


def title(ax, headline, subtitle):
    fig = ax.figure
    fig.text(0.015, 0.975, headline, fontsize=12.5, fontweight="bold", color=INK, va="top")
    fig.text(0.015, 0.905, subtitle, fontsize=9.5, color=INK_2, va="top")


def save(fig, name):
    fig.tight_layout(rect=(0, 0, 1, 0.85))
    fig.savefig(IMAGES / name, dpi=160)
    plt.close(fig)
    print(f"wrote images/{name}")


def funnel():
    path = RESULTS / "02_funnel_dropoff.csv"
    if not path.exists():
        return
    df = pd.read_csv(path)
    df = df[df["device_category"] == "All devices"].sort_values("step_number")
    # judge the steps after the cart: add_to_cart was not collected for the first weeks of the sample,
    # so the product page step is understated (see tracking_gap below)
    after_cart = df[(df["step_number"] >= 4) & (df["step_drop_off"] > 0)]
    worst = after_cart.sort_values("step_drop_off", ascending=False).iloc[0]
    fig, ax = plt.subplots(figsize=(8, 4.2))
    ax.barh(df["step_name"], df["sessions_closed"], color=SERIES[0], height=0.6)
    ax.invert_yaxis()
    for y, (n, share) in enumerate(zip(df["sessions_closed"], df["share_of_sessions"])):
        ax.text(n, y, f"  {n:,.0f}  ({share:.1%})", va="center", fontsize=9, color=INK)
    ax.set_xlabel("Sessions (closed funnel, all devices)")
    ax.margins(x=0.25)
    ax.xaxis.set_major_formatter(matplotlib.ticker.StrMethodFormatter("{x:,.0f}"))
    title(ax, f"{worst['step_drop_off']:.0%} of sessions with a cart never begin checkout",
          f"{worst['sessions_lost_at_step']:,.0f} sessions lost at that step, the largest loss after the product page")
    save(fig, "funnel.png")


def channels():
    path = RESULTS / "01_channel_performance.csv"
    if not path.exists():
        return
    df = pd.read_csv(path)
    df = df[df["sessions"] >= 100].sort_values("revenue_usd")
    direct = df[df["channel"] == "Direct"].iloc[0]
    fig, ax = plt.subplots(figsize=(8, 4.2))
    ax.barh(df["channel"], df["revenue_usd"], color=SERIES[0], height=0.6)
    for y, (rev, cr) in enumerate(zip(df["revenue_usd"], df["session_conversion_rate"])):
        ax.text(rev, y, f"  ${rev:,.0f}  ·  {cr:.2%} of sessions convert", va="center", fontsize=9, color=INK)
    ax.set_xlabel("Revenue (USD)")
    ax.xaxis.set_major_formatter(matplotlib.ticker.StrMethodFormatter("${x:,.0f}"))
    ax.margins(x=0.45)
    title(ax, f"Direct is {direct['share_of_sessions']:.0%} of sessions but only {direct['share_of_revenue']:.0%} of revenue",
          "Revenue by session channel, Google Merchandise Store, Nov 2020 to Jan 2021")
    save(fig, "channels.png")


def attribution():
    path = RESULTS / "04_attribution_first_vs_last.csv"
    if not path.exists():
        return
    df = pd.read_csv(path).sort_values("share_last_click")
    biggest = df.reindex(df["share_change_first_vs_last_click"].abs().sort_values().index).iloc[-1]
    b_first, b_last = biggest["share_first_touch"], biggest["share_last_click"]
    fig, ax = plt.subplots(figsize=(8, 4.8))
    h = 0.26
    ys = range(len(df))
    cols = [("share_first_touch", "First touch"), ("share_last_click", "Last click"), ("share_last_non_direct", "Last non direct")]
    for i, (col, label) in enumerate(cols):
        ax.barh([y + (1 - i) * (h + 0.02) for y in ys], df[col], height=h, color=SERIES[i], label=label)
    ax.set_yticks(list(ys))
    ax.set_yticklabels(df["channel"])
    ax.xaxis.set_major_formatter(matplotlib.ticker.PercentFormatter(1.0, decimals=0))
    ax.set_xlabel("Share of purchase revenue")
    ax.legend(frameon=False, loc="lower right", labelcolor=INK)
    title(ax, f"{biggest['channel']} is credited with {b_first:.0%} of revenue under first touch and {b_last:.0%} under last click",
          "Share of revenue each channel is credited with under three attribution models")
    save(fig, "attribution.png")


def landing_pages():
    path = RESULTS / "03_landing_pages.csv"
    if not path.exists():
        return
    df = pd.read_csv(path)
    df = df[df["landing_page"] != "(no page_view)"]  # sessions with no page view are a tracking issue, not a page
    df = df.sort_values("missed_conversions_vs_site", ascending=False).head(10)
    df = df[df["missed_conversions_vs_site"] > 0].sort_values("missed_conversions_vs_site")
    if df.empty:
        return
    top3 = df.tail(3)["missed_conversions_vs_site"].sum()
    labels = [p if len(p) <= 38 else p[:35] + "..." for p in df["landing_page"]]
    fig, ax = plt.subplots(figsize=(10, 4.8))
    ax.barh(labels, df["missed_conversions_vs_site"], color=SERIES[0], height=0.6)
    for y, (m, n, cr) in enumerate(zip(df["missed_conversions_vs_site"], df["sessions"], df["session_conversion_rate"])):
        ax.text(m, y, f"  {m:,.0f}  ({n:,.0f} sessions, {cr:.2%} convert)", va="center", fontsize=9, color=INK)
    ax.set_xlabel("Converting sessions missed against the site average")
    ax.margins(x=0.75)
    title(ax, f"Three landing pages account for {top3:,.0f} missed converting sessions",
          "Landing pages with 500+ sessions, ranked by conversions missed against the site average")
    save(fig, "landing_pages.png")


def tracking_gap():
    path = RESULTS / "05_ab_test_baseline.csv"
    if not path.exists():
        return
    df = pd.read_csv(path)
    df = df[~df["period"].str.startswith("Overall")]
    empty = df[df["sessions_added_to_cart"] == 0]
    fig, ax = plt.subplots(figsize=(8, 4.2))
    ax.bar(df["period"].str.replace("20", "", n=1), df["view_to_cart_rate"], color=SERIES[0], width=0.6)
    ax.grid(axis="x", visible=False)
    ax.grid(axis="y", visible=True)
    ax.yaxis.set_major_formatter(matplotlib.ticker.PercentFormatter(1.0, decimals=0))
    ax.set_ylabel("Product views that add to cart")
    ax.tick_params(axis="x", labelsize=8.5)
    for x, (rate, n) in enumerate(zip(df["view_to_cart_rate"], df["sessions_added_to_cart"])):
        ax.text(x, rate + 0.006, "0" if n == 0 else f"{rate:.0%}", ha="center", fontsize=8.5, color=INK)
    title(ax, f"No add to cart events were collected in the first {len(empty)} weeks",
          f"{empty['sessions_viewed_item'].sum():,.0f} product view sessions in those weeks show no cart activity: a tracking gap, not behaviour")
    save(fig, "tracking_gap.png")


if __name__ == "__main__":
    tracking_gap()
    funnel()
    channels()
    attribution()
    landing_pages()
