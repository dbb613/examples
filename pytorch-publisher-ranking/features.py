"""Shared definitions: the publisher attributes the model looks at, and the network itself."""
import torch
from torch import nn

# The "handful of attributes" describing each publisher site.
FEATURES = [
    "ctr",               # historical click-through rate (0-1)
    "viewability",       # share of impressions actually seen (0-1)
    "brand_safety",      # brand-safety score (0-1, higher is safer)
    "audience_match",    # overlap between site audience and our target (0-1)
    "avg_cpm",           # average cost per 1000 impressions, in dollars
    "fraud_rate",        # share of invalid / bot traffic (0-1)
    "page_load_sec",     # median page load time in seconds
]
TARGET = "roas"  # observed return on ad spend -- what "best" means here


class PublisherScorer(nn.Module):
    """Small MLP that maps a site's attributes to a predicted ROAS score.

    Normalisation stats are stored as buffers so they are saved with the
    weights and the model can be fed raw attribute values at inference time.
    """

    def __init__(self, n_features: int = len(FEATURES), hidden: int = 32):
        super().__init__()
        self.register_buffer("mean", torch.zeros(n_features))
        self.register_buffer("std", torch.ones(n_features))
        self.net = nn.Sequential(
            nn.Linear(n_features, hidden),
            nn.ReLU(),
            nn.Dropout(0.1),
            nn.Linear(hidden, hidden),
            nn.ReLU(),
            nn.Linear(hidden, 1),
        )

    def set_normalization(self, x: torch.Tensor) -> None:
        self.mean.copy_(x.mean(dim=0))
        self.std.copy_(x.std(dim=0).clamp_min(1e-6))

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        x = (x - self.mean) / self.std
        return self.net(x).squeeze(-1)
