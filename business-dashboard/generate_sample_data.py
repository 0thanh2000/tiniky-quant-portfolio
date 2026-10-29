"""Generate synthetic orders, using a fixed seed for reproducibility."""
import csv
import random
from datetime import date, timedelta
from pathlib import Path

rng = random.Random(7302)
products = {"Electronics": [("Wireless headphones", 89), ("Portable speaker", 65), ("Smart watch", 125)], "Home": [("Desk lamp", 39), ("Coffee maker", 75), ("Storage set", 29)], "Office": [("Notebook set", 18), ("Ergonomic mouse", 35), ("Desk organizer", 24)], "Fitness": [("Yoga mat", 32), ("Resistance bands", 22), ("Water bottle", 20)]}
regions = ["North", "South", "East", "West"]
start = date(2025, 1, 1)
path = Path(__file__).parent / "data" / "orders.csv"
path.parent.mkdir(parents=True, exist_ok=True)
with path.open("w", newline="", encoding="utf-8") as output:
    writer = csv.writer(output)
    writer.writerow(["order_id", "order_date", "region", "category", "product", "units", "revenue"])
    for i in range(1, 1601):
        day = start + timedelta(days=rng.randrange(638))
        category = rng.choice(list(products))
        product, price = rng.choice(products[category])
        units = rng.choices([1, 2, 3, 4], weights=[55, 27, 13, 5])[0]
        revenue = round(price * units * rng.uniform(0.9, 1.1), 2)
        writer.writerow([f"ORD-{i:05}", day.isoformat(), rng.choice(regions), category, product, units, revenue])
print(f"Wrote synthetic orders to {path}")
