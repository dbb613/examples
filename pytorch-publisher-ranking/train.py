"""Train PublisherScorer on historical site performance and save it to model.pt."""
import argparse
import csv

import torch
from torch import nn
from torch.utils.data import DataLoader, TensorDataset, random_split

from features import FEATURES, TARGET, PublisherScorer


def load(path: str):
    with open(path) as f:
        rows = list(csv.DictReader(f))
    x = torch.tensor([[float(r[c]) for c in FEATURES] for r in rows])
    y = torch.tensor([float(r[TARGET]) for r in rows])
    return x, y


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--data", default="data/history.csv")
    p.add_argument("--out", default="model.pt")
    p.add_argument("--epochs", type=int, default=60)
    p.add_argument("--lr", type=float, default=1e-3)
    args = p.parse_args()

    torch.manual_seed(0)
    x, y = load(args.data)

    # 1. Hold out 20% of sites to measure how well the model generalises.
    ds = TensorDataset(x, y)
    n_val = len(ds) // 5
    train_ds, val_ds = random_split(ds, [len(ds) - n_val, n_val])
    train_dl = DataLoader(train_ds, batch_size=64, shuffle=True)
    val_x, val_y = val_ds[:]

    # 2. Build the model; normalisation stats come from the training split only.
    model = PublisherScorer()
    model.set_normalization(train_ds[:][0])

    # 3. Loss + optimiser.
    loss_fn = nn.MSELoss()
    opt = torch.optim.Adam(model.parameters(), lr=args.lr, weight_decay=1e-4)

    # 4. Standard training loop.
    for epoch in range(1, args.epochs + 1):
        model.train()
        total = 0.0
        for xb, yb in train_dl:
            opt.zero_grad()
            loss = loss_fn(model(xb), yb)
            loss.backward()
            opt.step()
            total += loss.item() * len(xb)

        if epoch % 10 == 0 or epoch == 1:
            model.eval()
            with torch.no_grad():
                pred = model(val_x)
                val_mse = loss_fn(pred, val_y).item()
                # Ranking metric: of the true top-10% sites, how many did we put in our top 10%?
                k = max(1, len(val_y) // 10)
                hit = len(set(pred.topk(k).indices.tolist()) & set(val_y.topk(k).indices.tolist())) / k
            print(f"epoch {epoch:3d}  train_mse {total / len(train_ds):.4f}  "
                  f"val_mse {val_mse:.4f}  top10%_precision {hit:.2f}")

    # 5. Save weights (normalisation buffers are included in the state_dict).
    torch.save(model.state_dict(), args.out)
    print(f"saved {args.out}")


if __name__ == "__main__":
    main()
