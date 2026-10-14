<!--
title: 'PyTorch Publisher Site Ranking'
description: 'Train a small PyTorch model on publisher-site attributes and use it to rank the best sites to buy ads on.'
layout: Doc
framework: v3
platform: Local
language: python
authorLink: 'https://github.com/dbb613'
authorName: 'dbb613'
authorAvatar: 'https://avatars.githubusercontent.com/u/0?v=4'
-->

# Ranking publisher sites with PyTorch

A minimal, end-to-end example of **training** a PyTorch model and then **using** it.
The model learns which publisher sites perform best (highest return on ad spend)
from a handful of attributes, then ranks new candidate sites you haven't bought on yet.

## Attributes

| Feature          | Meaning                                    |
|------------------|--------------------------------------------|
| `ctr`            | historical click-through rate              |
| `viewability`    | share of impressions actually viewed       |
| `brand_safety`   | brand-safety score (higher is safer)       |
| `audience_match` | overlap with your target audience          |
| `avg_cpm`        | average cost per 1000 impressions ($)      |
| `fraud_rate`     | share of invalid / bot traffic             |
| `page_load_sec`  | median page load time                      |

The target is `roas` (observed return on ad spend). Edit `FEATURES` / `TARGET`
in `features.py` to use your own columns.

## Files

- `features.py` – the feature list and the model (`PublisherScorer`, a small MLP).
  Normalisation mean/std are stored as buffers, so they're saved with the weights.
- `generate_data.py` – creates synthetic `data/history.csv` (training data with
  `roas`) and `data/candidates.csv` (sites to rank). Swap in your real data here.
- `train.py` – train/validation split, `Adam` + `MSELoss` training loop, reports
  validation MSE and top-10% precision, saves `model.pt`.
- `rank.py` – loads `model.pt`, scores every candidate site, prints the top N.

## Run it

```bash
pip install -r requirements.txt
python generate_data.py
python train.py            # --epochs 60 --lr 1e-3
python rank.py --top 10    # --candidates path/to/your_sites.csv
```

Sample output:

```
epoch  60  train_mse 0.1108  val_mse 0.1091  top10%_precision 0.87
saved model.pt
rank  site                         pred_roas   ...
   1  publisher-2-0071.example          6.92   ...
   2  publisher-2-0120.example          5.64   ...
```

The synthetic data has noise variance ≈ 0.09, so a validation MSE of ~0.11 means
the model has learned nearly all of the real signal, and it puts ~87% of the
truly best sites in its own top 10%.

## Using your own data

1. Export one row per site with a `site` column, the feature columns, and the
   outcome you care about (ROAS, conversions per $1k, revenue per impression…).
2. Point `train.py --data` at it and `rank.py --candidates` at sites to score.
3. If you only have *relative* judgements ("site A beat site B"), switch the loss
   to a pairwise ranking loss such as `nn.MarginRankingLoss`; the model and
   `rank.py` stay the same.
