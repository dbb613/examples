"""Use a trained model to score new publisher sites and print the best ones."""
import argparse
import csv

import torch

from features import FEATURES, PublisherScorer


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--model", default="model.pt")
    p.add_argument("--candidates", default="data/candidates.csv")
    p.add_argument("--top", type=int, default=10)
    args = p.parse_args()

    model = PublisherScorer()
    model.load_state_dict(torch.load(args.model, weights_only=True))
    model.eval()  # turns off dropout

    with open(args.candidates) as f:
        rows = list(csv.DictReader(f))
    x = torch.tensor([[float(r[c]) for c in FEATURES] for r in rows])

    with torch.no_grad():
        scores = model(x)

    order = scores.argsort(descending=True)[: args.top]
    print(f"{'rank':>4}  {'site':<28} {'pred_roas':>9}  " + "  ".join(f"{c:>14}" for c in FEATURES))
    for rank, i in enumerate(order.tolist(), 1):
        r = rows[i]
        print(f"{rank:>4}  {r['site']:<28} {scores[i].item():>9.2f}  "
              + "  ".join(f"{float(r[c]):>14.3f}" for c in FEATURES))


if __name__ == "__main__":
    main()
