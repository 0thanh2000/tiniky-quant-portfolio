# -*- coding: utf-8 -*-
"""
================================================================================
📊 BACKTEST LSTM AI — GBPUSD
Đã đồng bộ: Train ↔ Backtest ↔ Bot Live
================================================================================

✅ ĐÃ SỬA (bản này) — GIẢI QUYẾT RÒ RỈ DỮ LIỆU:
  Bản trước backtest bắt đầu từ split_info["train_end_idx"] — đúng chỗ mà
  file Train cũng dùng làm tập Validation để EarlyStopping/ModelCheckpoint/
  ReduceLROnPlateau chọn mô hình. Nghĩa là backtest đã "vô tình" đánh giá
  trên đúng dữ liệu đã giúp chọn ra mô hình này — không phải out-of-sample
  thật sự, nên kết quả lạc quan hơn thực tế.

  → ĐÃ SỬA: Train giờ chia 3 phần (Train/Val/Test) và lưu thêm
  split_info["val_end_idx"] — ranh giới bắt đầu tập TEST thật sự, hoàn toàn
  không đụng tới ở bất kỳ bước nào của quá trình train. Backtest giờ đọc
  val_end_idx thay vì train_end_idx làm điểm bắt đầu.
  ⚠️ File split_info_{PAIR}.save PHẢI được tạo lại từ bản Train mới (có lưu
  val_end_idx) trước khi chạy backtest này — nếu dùng file split_info cũ
  (chỉ có train_end_idx, chưa có val_end_idx) backtest sẽ báo lỗi KeyError.

✅ Các fix giữ nguyên từ bản trước (đã kiểm chứng đúng, không đổi):
  1. MODEL_TAG khớp chính xác với Train.
  2. Đường dẫn scaler/split_info dùng DRIVE_DIR giống Train.
  3. Kiểm tra đồng bộ nến ĐỦ CẢ 3 khung M5/M15/M30, khớp Train.
  4. Spread ước lượng động theo biến động (proxy, không phải spread lịch sử
     thật — xem ghi chú chi tiết ở mục 5b bên dưới).
================================================================================
"""
import os
import joblib
import numpy as np
import pandas as pd
import tensorflow as tf

try:
    from google.colab import files
    IN_COLAB = True
except ImportError:
    IN_COLAB = False


# ==========================================================================
# 1. CẤU HÌNH — 100% KHỚP TRAIN & BOT
# ==========================================================================
PAIR = "GBPUSD"

MODEL_TAG = "GU_Delta_300step_Optimized_PureLSTM"

DRIVE_DIR = "/content/drive/MyDrive/" if IN_COLAB else "./"

# TimeSteps — KHỚP TRAIN & BOT
TIME_STEPS_M5 = 300
TIME_STEPS_M15 = 300
TIME_STEPS_M30 = 300
TIME_STEPS_H1 = 300

# Dự báo delta sau 4 nến H1
N_STEPS = 4

PIP_SIZE = 0.0001

# Chi phí giao dịch — SPREAD_PIPS giờ là spread NỀN (baseline), sẽ được
# nhân thêm hệ số biến động cho từng lệnh (xem mục 5b)
SPREAD_PIPS = 1.8
SLIPPAGE_PIPS = 1.0
MAX_SPREAD_PIPS = 4.0
SLIPPAGE = SLIPPAGE_PIPS * PIP_SIZE

SPREAD_VOL_MULTIPLIER_CAP = 3.0

# Ngưỡng tín hiệu
# ✅ SỬA: chọn cách lọc tín hiệu
USE_PERCENTILE_THRESHOLD = True    # True: lấy top X% dự báo mạnh nhất; False: dùng ngưỡng cố định
PRED_PERCENTILE = 90               # chỉ vào lệnh khi |dự báo| thuộc top 10%
MIN_PRED_PIPS = 8.0                # ngưỡng cố định (chỉ dùng khi USE_PERCENTILE_THRESHOLD = False)

# Rủi ro / Lợi nhuận
RR_RATIO = 1.3
SL_RATIO = 1.0 / RR_RATIO

# Quản lý vị thế
MAX_HOLD_HOURS = 12
BE_ENABLED = True
BE_TRIGGER_PIPS = 10.0
BE_LOCK_PIPS = 2.0
TRAILING_ENABLED = True
TRAILING_TRIGGER_PIPS = 15.0
TRAILING_DISTANCE_PIPS = 5.0

# Đặc trưng — KHỚP
FEATURE_ORDER = [
    "Return",
    "Body",
    "Range",
    "Upper_Wick",
    "Lower_Wick",
    "Dist_SMA20",
    "Dist_SMA50",
    "Rel_Vol",
    "Time_Delta",
]


# ==========================================================================
# 2. FEATURE ENGINEERING — KHỚP TRAIN
# ==========================================================================
def extract_stationary_features(df):
    df_out = pd.DataFrame(index=df.index)

    close = df["Close"]
    open_p = df["Open"]
    high = df["High"]
    low = df["Low"]

    df_out["Return"] = close.pct_change().fillna(0)
    df_out["Body"] = (close - open_p) / open_p
    df_out["Range"] = (high - low) / open_p

    df_out["Upper_Wick"] = (
        high - df[["Open", "Close"]].max(axis=1)
    ) / open_p

    df_out["Lower_Wick"] = (
        df[["Open", "Close"]].min(axis=1) - low
    ) / open_p

    sma20 = close.rolling(20, min_periods=20).mean()
    sma50 = close.rolling(50, min_periods=50).mean()

    df_out["Dist_SMA20"] = (close - sma20) / sma20
    df_out["Dist_SMA50"] = (close - sma50) / sma50

    vol20 = df_out["Range"].rolling(20, min_periods=20).mean()
    df_out["Rel_Vol"] = df_out["Range"] / (vol20 + 1e-8)

    time_diff = df["Datetime"].diff().dt.total_seconds() / 60.0
    df_out["Time_Delta"] = np.log1p(time_diff.fillna(0))

    return df_out[FEATURE_ORDER].replace([np.inf, -np.inf], np.nan).fillna(0)


# ==========================================================================
# 3. LOAD CSV
# ==========================================================================
def load_and_clean_csv(file_path):
    df = pd.read_csv(
        file_path,
        sep=r"\s+",
        header=None,
        names=["Date", "Time", "Open", "High", "Low", "Close", "Volume"],
        engine="python",
    )

    df["Datetime"] = pd.to_datetime(
        df["Date"].astype(str) + " " + df["Time"].astype(str),
        format="%Y.%m.%d %H:%M",
    )

    df = df[["Datetime", "Open", "High", "Low", "Close"]].copy()

    for col in ["Open", "High", "Low", "Close"]:
        df[col] = pd.to_numeric(df[col], errors="coerce")

    df.sort_values("Datetime", inplace=True)
    df.dropna(subset=["Datetime", "Open", "High", "Low", "Close"], inplace=True)
    df.drop_duplicates(subset=["Datetime"], keep="last", inplace=True)
    df.reset_index(drop=True, inplace=True)

    return df


# ==========================================================================
# 4. LOAD DỮ LIỆU & SCALERS
# ==========================================================================
print("🔄 Đang tải dữ liệu & scalers...")

df_m5_raw = load_and_clean_csv(f"{PAIR}_M5.csv")
df_m15_raw = load_and_clean_csv(f"{PAIR}_M15.csv")
df_m30_raw = load_and_clean_csv(f"{PAIR}_M30.csv")
df_h1_raw = load_and_clean_csv(f"{PAIR}_H1.csv")

feat_m5 = extract_stationary_features(df_m5_raw)
feat_m15 = extract_stationary_features(df_m15_raw)
feat_m30 = extract_stationary_features(df_m30_raw)
feat_h1 = extract_stationary_features(df_h1_raw)

scaler_m5 = joblib.load(os.path.join(DRIVE_DIR, f"scaler_m5_{PAIR}.save"))
scaler_m15 = joblib.load(os.path.join(DRIVE_DIR, f"scaler_m15_{PAIR}.save"))
scaler_m30 = joblib.load(os.path.join(DRIVE_DIR, f"scaler_m30_{PAIR}.save"))
scaler_h1 = joblib.load(os.path.join(DRIVE_DIR, f"scaler_h1_{PAIR}.save"))
scaler_target = joblib.load(os.path.join(DRIVE_DIR, f"scaler_target_{PAIR}.save"))

split_info = joblib.load(os.path.join(DRIVE_DIR, f"split_info_{PAIR}.save"))

# ✅ ĐÃ SỬA: dùng val_end_idx (ranh giới TEST thật sự) thay vì train_end_idx.
# split_info cũ (từ bản Train trước khi sửa) không có key này — báo lỗi rõ
# ràng thay vì âm thầm dùng nhầm train_end_idx.
if "val_end_idx" not in split_info:
    raise KeyError(
        "split_info_{}.save không có 'val_end_idx' — file này được tạo từ "
        "bản Train CŨ (chỉ chia Train/Validation 2 phần). Hãy chạy lại file "
        "Train đã sửa (chia 3 phần Train/Val/Test) để tạo lại split_info "
        "trước khi backtest, nếu không kết quả sẽ bị rò rỉ dữ liệu "
        "Validation vào backtest.".format(PAIR)
    )

test_start = int(split_info["val_end_idx"])
print(f"✅ Test start index (val_end_idx): {test_start}")
print(f"✅ Test start time              : {df_h1_raw['Datetime'].iloc[test_start]}")
print("   (Đây là phần dữ liệu hoàn toàn chưa được Train nhìn thấy ở bất kỳ")
print("    bước nào — không fit scaler, không early-stop, không checkpoint.)")


# ==========================================================================
# 5. SCALE & TẠO SEQUENCES
# ==========================================================================
data_m5_s = pd.DataFrame(
    scaler_m5.transform(feat_m5[FEATURE_ORDER]),
    columns=FEATURE_ORDER,
    index=df_m5_raw["Datetime"],
)
data_m15_s = pd.DataFrame(
    scaler_m15.transform(feat_m15[FEATURE_ORDER]),
    columns=FEATURE_ORDER,
    index=df_m15_raw["Datetime"],
)
data_m30_s = pd.DataFrame(
    scaler_m30.transform(feat_m30[FEATURE_ORDER]),
    columns=FEATURE_ORDER,
    index=df_m30_raw["Datetime"],
)
data_h1_s = pd.DataFrame(
    scaler_h1.transform(feat_h1[FEATURE_ORDER]),
    columns=FEATURE_ORDER,
    index=df_h1_raw["Datetime"],
)

arr_m5 = data_m5_s.values
arr_m15 = data_m15_s.values
arr_m30 = data_m30_s.values
arr_h1 = data_h1_s.values

idx_m5 = data_m5_s.index.values.astype("datetime64[ns]")
idx_m15 = data_m15_s.index.values.astype("datetime64[ns]")
idx_m30 = data_m30_s.index.values.astype("datetime64[ns]")
idx_h1 = data_h1_s.index.values.astype("datetime64[ns]")

one_hour = np.timedelta64(1, "h")

# Tạo mẫu OOS (Out-Of-Sample = tập Test thật sự, từ test_start trở đi)
X_m5_list = []
X_m15_list = []
X_m30_list = []
X_h1_list = []
oos_h1_indices = []

start_idx = max(TIME_STEPS_H1 - 1, test_start)

for i in range(start_idx, len(df_h1_raw) - N_STEPS):
    t_open_h1 = idx_h1[i]
    t_close_h1 = t_open_h1 + one_hour

    pos_m5 = np.searchsorted(idx_m5, t_close_h1, side="left")
    pos_m15 = np.searchsorted(idx_m15, t_close_h1, side="left")
    pos_m30 = np.searchsorted(idx_m30, t_close_h1, side="left")

    if pos_m5 <= 0 or pos_m15 <= 0 or pos_m30 <= 0:
        continue

    last_m5_time = idx_m5[pos_m5 - 1]
    last_m15_time = idx_m15[pos_m15 - 1]
    last_m30_time = idx_m30[pos_m30 - 1]

    if not (
        (t_open_h1 <= last_m5_time < t_close_h1)
        and (t_open_h1 <= last_m15_time < t_close_h1)
        and (t_open_h1 <= last_m30_time < t_close_h1)
    ):
        continue

    if (pos_m5 < TIME_STEPS_M5 or
        pos_m15 < TIME_STEPS_M15 or
        pos_m30 < TIME_STEPS_M30):
        continue

    X_m5_list.append(arr_m5[pos_m5 - TIME_STEPS_M5 : pos_m5])
    X_m15_list.append(arr_m15[pos_m15 - TIME_STEPS_M15 : pos_m15])
    X_m30_list.append(arr_m30[pos_m30 - TIME_STEPS_M30 : pos_m30])
    X_h1_list.append(arr_h1[i - TIME_STEPS_H1 + 1 : i + 1])

    oos_h1_indices.append(i)

X_m5_arr = np.asarray(X_m5_list, dtype=np.float32)
X_m15_arr = np.asarray(X_m15_list, dtype=np.float32)
X_m30_arr = np.asarray(X_m30_list, dtype=np.float32)
X_h1_arr = np.asarray(X_h1_list, dtype=np.float32)

print(f"✅ Số mẫu OOS (Test thật sự): {len(oos_h1_indices):,}")


# ==========================================================================
# 5b. ƯỚC LƯỢNG SPREAD ĐỘNG THEO BIẾN ĐỘNG (PROXY — không đổi)
# ==========================================================================
# Không có dữ liệu spread lịch sử thật trong CSV (chỉ có OHLC), nên ta ước
# lượng spread mỗi nến H1 dựa trên biến động giá của chính nến đó so với
# biến động trung bình 20 nến gần nhất. Đây là XẤP XỈ, không phải spread thật.
h1_range_raw = (df_h1_raw["High"] - df_h1_raw["Low"]) / df_h1_raw["Open"]
h1_vol20_raw = h1_range_raw.rolling(20, min_periods=20).mean()
h1_range_ratio = (h1_range_raw / (h1_vol20_raw + 1e-8)).fillna(1.0)
h1_range_ratio = h1_range_ratio.replace([np.inf, -np.inf], 1.0)

estimated_spread_pips_arr = SPREAD_PIPS * h1_range_ratio.clip(lower=1.0, upper=SPREAD_VOL_MULTIPLIER_CAP)
estimated_spread_pips_arr = estimated_spread_pips_arr.values


# ==========================================================================
# 6. CUSTOM LOSS — KHỚP 100%
# ==========================================================================
@tf.keras.utils.register_keras_serializable(
    package="Custom",
    name="directional_huber_loss",
)
def directional_huber_loss(y_true, y_pred, delta=0.15, penalty_weight=2.5):
    error = y_true - y_pred
    abs_error = tf.abs(error)
    huber_loss = tf.where(
        abs_error <= delta,
        0.5 * tf.square(error),
        delta * (abs_error - 0.5 * delta),
    )
    same_direction = tf.cast(
        tf.equal(tf.sign(y_true), tf.sign(y_pred)),
        tf.float32,
    )
    direction_penalty = tf.where(same_direction > 0.5, 1.0, penalty_weight)
    return tf.reduce_mean(huber_loss * direction_penalty)


# ==========================================================================
# 7. LOAD MODEL & DỰ BÁO
# ==========================================================================
model_path = os.path.join(DRIVE_DIR, f"{MODEL_TAG}.keras")
print(f"🔄 Đang tải model: {model_path}")

model = tf.keras.models.load_model(
    model_path,
    custom_objects={"directional_huber_loss": directional_huber_loss},
)

print("🤖 Đang dự báo...")
pred_scaled = model.predict(
    {
        "input_m5": X_m5_arr,
        "input_m15": X_m15_arr,
        "input_m30": X_m30_arr,
        "input_h1": X_h1_arr,
    },
    batch_size=64,
    verbose=1,
)

pred_delta = scaler_target.inverse_transform(pred_scaled).flatten()

# ==========================================================================
# ✅ THÊM: CHẨN ĐOÁN CHẤT LƯỢNG DỰ BÁO (chạy trước khi backtest)
# ==========================================================================
pred_pips_all = np.abs(pred_delta) / PIP_SIZE
print("\n--- CHẨN ĐOÁN DỰ BÁO ---")
print("Phân vị |dự báo| (pips) [50,75,90,95,99,max]:",
      np.percentile(pred_pips_all, [50, 75, 90, 95, 99, 100]).round(2))
print("Std dự báo (pips):", (pred_delta / PIP_SIZE).std().round(2))

actual_delta = (df_h1_raw["Close"].shift(-N_STEPS) - df_h1_raw["Close"]).values
act = actual_delta[oos_h1_indices]
print("Std delta thực (pips):", (act / PIP_SIZE).std().round(2))
print("Directional accuracy :", (np.sign(act) == np.sign(pred_delta)).mean().round(4))
print("Correlation          :", np.corrcoef(act, pred_delta)[0, 1].round(4))
print("Số mẫu có |dự báo| >= MIN_PRED_PIPS:", int((pred_pips_all >= MIN_PRED_PIPS).sum()),
      "/", len(pred_pips_all))
print("--------------------------\n")


# ==========================================================================
# 8. BACKTEST ENGINE (không đổi so với bản trước)
# ==========================================================================
def pips_to_price(pips):
    return pips * PIP_SIZE

def apply_buy_entry(bid_close, spread_price):
    ask = bid_close + spread_price
    return ask + SLIPPAGE

def apply_sell_entry(bid_close):
    return bid_close - SLIPPAGE


print("📊 Chạy backtest...")
# ✅ THÊM: tính ngưỡng thực tế dùng trong backtest
if USE_PERCENTILE_THRESHOLD:
    effective_min_pips = float(np.percentile(pred_pips_all, PRED_PERCENTILE))
    print(f"Ngưỡng theo phân vị {PRED_PERCENTILE}: {effective_min_pips:.2f} pips")
else:
    effective_min_pips = MIN_PRED_PIPS
trades = []
last_exit_bar_idx = -1
skipped_due_to_spread = 0

for seq_idx, i in enumerate(oos_h1_indices):
    if i <= last_exit_bar_idx:
        continue

    estimated_spread_pips = float(estimated_spread_pips_arr[i])
    if estimated_spread_pips > MAX_SPREAD_PIPS:
        skipped_due_to_spread += 1
        continue

    spread_price = estimated_spread_pips * PIP_SIZE

    predicted_delta = float(pred_delta[seq_idx])
    abs_delta = abs(predicted_delta)
    pred_pips = abs_delta / PIP_SIZE

    if pred_pips < effective_min_pips:
        continue

    entry_time = df_h1_raw["Datetime"].iloc[i]
    bid_close = float(df_h1_raw["Close"].iloc[i])
    direction = "BUY" if predicted_delta > 0 else "SELL"

    entry_price = (
        apply_buy_entry(bid_close, spread_price)
        if direction == "BUY"
        else apply_sell_entry(bid_close)
    )

    risk_price = abs_delta * SL_RATIO
    reward_price = abs_delta

    if direction == "BUY":
        tp_price = entry_price + reward_price
        sl_price = entry_price - risk_price
    else:
        tp_price = entry_price - reward_price
        sl_price = entry_price + risk_price

    current_sl = sl_price
    be_activated = False
    trailing_activated = False
    trade_closed = False
    exit_price = np.nan
    exit_time = None
    exit_reason = None
    exit_bar_idx = None

    max_step = min(MAX_HOLD_HOURS, len(df_h1_raw) - i - 1)

    for step in range(1, max_step + 1):
        future_idx = i + step
        bar = df_h1_raw.iloc[future_idx]
        bar_time = bar["Datetime"]
        bid_high = float(bar["High"])
        bid_low = float(bar["Low"])
        bid_close_future = float(bar["Close"])

        if direction == "BUY":
            hit_sl = bid_low <= current_sl
            hit_tp = bid_high >= tp_price

            if hit_sl and hit_tp:
                exit_price = current_sl
                exit_reason = "SL"
                trade_closed = True
                exit_time = bar_time
                exit_bar_idx = future_idx
                break
            elif hit_sl:
                exit_price = current_sl
                exit_reason = "SL"
                trade_closed = True
                exit_time = bar_time
                exit_bar_idx = future_idx
                break
            elif hit_tp:
                exit_price = tp_price
                exit_reason = "TP"
                trade_closed = True
                exit_time = bar_time
                exit_bar_idx = future_idx
                break

            profit_pips_high = (bid_high - entry_price) / PIP_SIZE
            if BE_ENABLED and not be_activated and profit_pips_high >= BE_TRIGGER_PIPS:
                be_sl = entry_price + pips_to_price(BE_LOCK_PIPS)
                current_sl = max(current_sl, be_sl)
                be_activated = True

            if TRAILING_ENABLED and profit_pips_high >= TRAILING_TRIGGER_PIPS:
                trailing_sl = bid_high - pips_to_price(TRAILING_DISTANCE_PIPS)
                current_sl = max(current_sl, trailing_sl)
                trailing_activated = True

        else:
            ask_high = bid_high + spread_price
            ask_low = bid_low + spread_price
            ask_close = bid_close_future + spread_price

            hit_sl = ask_high >= current_sl
            hit_tp = ask_low <= tp_price

            if hit_sl and hit_tp:
                exit_price = current_sl
                exit_reason = "SL"
                trade_closed = True
                exit_time = bar_time
                exit_bar_idx = future_idx
                break
            elif hit_sl:
                exit_price = current_sl
                exit_reason = "SL"
                trade_closed = True
                exit_time = bar_time
                exit_bar_idx = future_idx
                break
            elif hit_tp:
                exit_price = tp_price
                exit_reason = "TP"
                trade_closed = True
                exit_time = bar_time
                exit_bar_idx = future_idx
                break

            profit_pips_high = (entry_price - ask_low) / PIP_SIZE
            if BE_ENABLED and not be_activated and profit_pips_high >= BE_TRIGGER_PIPS:
                be_sl = entry_price - pips_to_price(BE_LOCK_PIPS)
                current_sl = min(current_sl, be_sl)
                be_activated = True

            if TRAILING_ENABLED and profit_pips_high >= TRAILING_TRIGGER_PIPS:
                trailing_sl = ask_low + pips_to_price(TRAILING_DISTANCE_PIPS)
                current_sl = min(current_sl, trailing_sl)
                trailing_activated = True

    if not trade_closed:
        future_idx = min(i + max_step, len(df_h1_raw) - 1)
        bar = df_h1_raw.iloc[future_idx]
        exit_time = bar["Datetime"]
        exit_bar_idx = future_idx
        exit_reason = "TIME_EXPIRE"

        if direction == "BUY":
            bid_close = float(bar["Close"])
            exit_price = bid_close - SLIPPAGE
        else:
            bid_close = float(bar["Close"])
            ask_close = bid_close + spread_price
            exit_price = ask_close + SLIPPAGE

    pips_gained = (exit_price - entry_price) / PIP_SIZE if direction == "BUY" else (entry_price - exit_price) / PIP_SIZE

    trades.append({
        "Entry_Time": entry_time,
        "Exit_Time": exit_time,
        "Direction": direction,
        "Entry_Price": entry_price,
        "Exit_Price": exit_price,
        "Est_Spread_Pips": estimated_spread_pips,
        "Pred_Delta_Pips": pred_pips,
        "Initial_SL_Pips": risk_price / PIP_SIZE,
        "Initial_TP_Pips": reward_price / PIP_SIZE,
        "Pips_Gained": pips_gained,
        "Reason": exit_reason,
        "BE_Activated": be_activated,
        "Trailing_Activated": trailing_activated,
        "Hold_Hours": exit_bar_idx - i,
    })

    last_exit_bar_idx = exit_bar_idx

print(f"⚠️  Số lệnh bị bỏ qua do spread ước lượng > {MAX_SPREAD_PIPS:.1f} pips: {skipped_due_to_spread}")


# ==========================================================================
# 9. BÁO CÁO KẾT QUẢ
# ==========================================================================
df_trades = pd.DataFrame(trades)

if len(df_trades) == 0:
    print("\n❌ Không có lệnh nào được kích hoạt.")
    print("Kiểm tra MIN_PRED_PIPS, dữ liệu hoặc model.")
else:
    df_trades["Cumulative_Pips"] = df_trades["Pips_Gained"].cumsum()

    win_trades = df_trades[df_trades["Pips_Gained"] > 0]
    loss_trades = df_trades[df_trades["Pips_Gained"] <= 0]
    total_trades = len(df_trades)
    win_rate = len(win_trades) / total_trades * 100
    net_pips = df_trades["Pips_Gained"].sum()
    total_win_pips = win_trades["Pips_Gained"].sum() if len(win_trades) > 0 else 0
    total_loss_pips = abs(loss_trades["Pips_Gained"].sum()) if len(loss_trades) > 0 else 0
    profit_factor = total_win_pips / total_loss_pips if total_loss_pips > 0 else np.nan

    cum_pips = df_trades["Cumulative_Pips"]
    peak = cum_pips.cummax()
    drawdown = cum_pips - peak
    max_drawdown = drawdown.min()

    be_count = int(df_trades["BE_Activated"].sum())
    trailing_count = int(df_trades["Trailing_Activated"].sum())
    tp_count = int((df_trades["Reason"] == "TP").sum())
    sl_count = int((df_trades["Reason"] == "SL").sum())
    expiry_count = int((df_trades["Reason"] == "TIME_EXPIRE").sum())

    print("\n" + "="*60)
    print(f"📊 KẾT QUẢ BACKTEST (trên tập TEST — chưa từng bị Train nhìn thấy) — {PAIR}")
    print("="*60)
    print(f"RR Ratio             : 1 : {RR_RATIO}")
    print(f"Min Prediction       : {effective_min_pips:.1f} pips")
    print(f"Spread nền           : {SPREAD_PIPS:.1f} pips (giãn tối đa x{SPREAD_VOL_MULTIPLIER_CAP:.1f} theo biến động)")
    print(f"Spread ước lượng TB  : {df_trades['Est_Spread_Pips'].mean():.2f} pips")
    print(f"Slippage             : {SLIPPAGE_PIPS:.1f} pips")
    print(f"Max Hold             : {MAX_HOLD_HOURS} giờ")
    print(f"Break-even           : +{BE_TRIGGER_PIPS:.1f} → +{BE_LOCK_PIPS:.1f} pips")
    print(f"Trailing Stop        : +{TRAILING_TRIGGER_PIPS:.1f} / {TRAILING_DISTANCE_PIPS:.1f} pips")
    print("-"*60)
    print(f"Tổng số lệnh         : {total_trades}")
    print(f"Bỏ qua do spread rộng: {skipped_due_to_spread}")
    print(f"Tỷ lệ thắng          : {win_rate:.2f}%")
    print(f"Tổng Pips ròng       : {net_pips:.1f}")
    print(f"Profit Factor        : {profit_factor:.2f}")
    print(f"Max Drawdown         : {max_drawdown:.1f} pips")
    print(f"Trung bình/lệnh     : {df_trades['Pips_Gained'].mean():.2f} pips")
    print("-"*60)
    print(f"Chạm TP              : {tp_count}")
    print(f"Chạm SL              : {sl_count}")
    print(f"Hết thời gian        : {expiry_count}")
    print(f"BE đã kích hoạt      : {be_count}")
    print(f"Trailing đã kích hoạt: {trailing_count}")
    print("="*60)

    output_file = f"backtest_results_{PAIR}.csv"
    df_trades.to_csv(output_file, index=False)
    print(f"\n✅ Đã lưu kết quả: {output_file}")
