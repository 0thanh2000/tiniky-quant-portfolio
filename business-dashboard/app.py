"""Interactive business dashboard using an entirely synthetic order dataset."""

from pathlib import Path

import pandas as pd
import plotly.express as px
import streamlit as st

DATA = Path(__file__).parent / "data" / "orders.csv"
COLORS = ["#10b981", "#0e7490", "#6366f1", "#f59e0b"]

st.set_page_config(page_title="Business Performance Dashboard", page_icon="📊", layout="wide")
st.title("Business performance dashboard")
st.caption("A portfolio demonstration using synthetic data · USD · One row per order")

@st.cache_data
def load_data():
    df = pd.read_csv(DATA, parse_dates=["order_date"])
    df["revenue"] = df["revenue"].astype(float)
    return df

df = load_data()
with st.sidebar:
    st.header("Filters")
    min_date, max_date = df.order_date.min().date(), df.order_date.max().date()
    period = st.date_input("Order date", value=(min_date, max_date), min_value=min_date, max_value=max_date)
    categories = st.multiselect("Category", sorted(df.category.unique()), default=sorted(df.category.unique()))
    regions = st.multiselect("Region", sorted(df.region.unique()), default=sorted(df.region.unique()))
    st.caption("All data was generated for this demo. No customer or company records are included.")

if not isinstance(period, (list, tuple)) or len(period) != 2:
    st.info("Select both a start and end date to view the dashboard.")
    st.stop()

start, end = period
filtered = df.loc[df.order_date.between(pd.Timestamp(start), pd.Timestamp(end)) & df.category.isin(categories) & df.region.isin(regions)].copy()
if filtered.empty:
    st.info("No orders match these filters. Select another date, category or region.")
    st.stop()

revenue = filtered.revenue.sum()
orders = len(filtered)
units = int(filtered.units.sum())
c1, c2, c3, c4 = st.columns(4)
c1.metric("Revenue", f"${revenue:,.0f}")
c2.metric("Orders", f"{orders:,}")
c3.metric("Average order value", f"${revenue / orders:,.2f}")
c4.metric("Units sold", f"{units:,}")
st.divider()

monthly = filtered.assign(month=filtered.order_date.dt.to_period("M").dt.to_timestamp()).groupby("month", as_index=False).agg(revenue=("revenue", "sum"), orders=("order_id", "count"))
by_category = filtered.groupby("category", as_index=False).agg(revenue=("revenue", "sum")).sort_values("revenue", ascending=False)
by_region = filtered.groupby("region", as_index=False).agg(revenue=("revenue", "sum")).sort_values("revenue", ascending=False)
products = filtered.groupby("product", as_index=False).agg(orders=("order_id", "count"), units=("units", "sum"), revenue=("revenue", "sum")).sort_values("revenue", ascending=False)

left, right = st.columns([1.6, 1])
with left:
    st.subheader("Revenue over time")
    fig = px.area(monthly, x="month", y="revenue", markers=True, color_discrete_sequence=COLORS, labels={"month": "Month", "revenue": "Revenue (USD)"})
    fig.update_layout(margin=dict(l=0, r=0, t=10, b=0), hovermode="x unified")
    st.plotly_chart(fig, width='stretch')
with right:
    st.subheader("Revenue by category")
    fig = px.pie(by_category, values="revenue", names="category", hole=0.62, color_discrete_sequence=COLORS)
    fig.update_layout(margin=dict(l=0, r=0, t=10, b=0), legend_title_text="")
    st.plotly_chart(fig, width='stretch')

left, right = st.columns(2)
with left:
    st.subheader("Revenue by region")
    fig = px.bar(by_region, x="revenue", y="region", orientation="h", color_discrete_sequence=COLORS, labels={"region": "", "revenue": "Revenue (USD)"})
    fig.update_layout(margin=dict(l=0, r=0, t=10, b=0), yaxis={"categoryorder": "total ascending"})
    st.plotly_chart(fig, width='stretch')
with right:
    st.subheader("Top products")
    st.dataframe(products.head(10), hide_index=True, width='stretch', column_config={"product": "Product", "orders": "Orders", "units": "Units", "revenue": st.column_config.NumberColumn("Revenue", format="$%.2f")})

with st.expander("View filtered order data"):
    st.dataframe(filtered.sort_values("order_date", ascending=False), hide_index=True, width='stretch')
st.download_button("Download filtered orders as CSV", filtered.to_csv(index=False).encode("utf-8"), "filtered_orders.csv", "text/csv")
st.caption("Revenue is the sum of order revenue. Average order value is revenue divided by order count. Totals follow the selected filters.")

