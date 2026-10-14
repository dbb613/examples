"""Generate a synthetic history of publisher sites and the ROAS each delivered.

Replace this with your real campaign data: one row per site, the FEATURES
columns, and the observed outcome in the TARGET column.
"""
import csv
import os
import random

from features import FEATURES, TARGET


def true_roas(s: dict) -> float:
    # Hidden "ground truth" the model has to discover. Non-linear on purpose:
    # fraud and slow pages hurt a lot, cheap CPM only helps if the audience fits.
    value = (
        8.0 * s["ctr"] * 10
        + 2.5 * s["viewability"]
        + 1.5 * s["brand_safety"]
        + 3.0 * s["audience_match"] * (1.0 / (1.0 + s["avg_cpm"] / 10))
        - 6.0 * s["fraud_rate"] ** 0.5
        - 0.4 * max(0.0, s["page_load_sec"] - 2.0)
    )
    return max(0.0, value)


def random_site(rng: random.Random) -> dict:
    return {
        "ctr": rng.betavariate(2, 120),
        "viewability": rng.uniform(0.3, 0.95),
        "brand_safety": rng.betavariate(5, 2),
        "audience_match": rng.uniform(0, 1),
        "avg_cpm": rng.uniform(1, 25),
        "fraud_rate": rng.betavariate(1.2, 15),
        "page_load_sec": rng.uniform(0.8, 7.0),
    }


def write_csv(path: str, n: int, seed: int, with_target: bool) -> None:
    rng = random.Random(seed)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", newline="") as f:
        cols = ["site"] + FEATURES + ([TARGET] if with_target else [])
        w = csv.DictWriter(f, fieldnames=cols)
        w.writeheader()
        for i in range(n):
            s = random_site(rng)
            row = {"site": f"publisher-{seed}-{i:04d}.example", **{k: round(v, 4) for k, v in s.items()}}
            if with_target:
                row[TARGET] = round(true_roas(s) + rng.gauss(0, 0.3), 4)  # noisy observation
            w.writerow(row)


if __name__ == "__main__":
    write_csv("data/history.csv", n=5000, seed=1, with_target=True)
    write_csv("data/candidates.csv", n=200, seed=2, with_target=False)
    print("wrote data/history.csv (training) and data/candidates.csv (sites to rank)")
