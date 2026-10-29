# -*- coding: utf-8 -*-
"""
================================================================================
BẢN ĐÃ TỐI ƯU RAM — TRAIN TRÊN COLAB 12GB OK
- Sinh sequence bằng generator (chỉ giữ ~60MB mảng 2D gốc, không build mảng 3D khổng lồ)
- Generator yield cả batch (nhanh gấp 32 lần so với yield từng mẫu)
- Dọn RAM đúng thời điểm (không xóa biến còn dùng)
- clear_session() chỉ gọi 1 lần ở đầu, KHÔNG gọi giữa chừng khi đang train
- Chia 3 phần Train/Val/Test, không rò rỉ dữ liệu
================================================================================
"""
import os
import gc                                    # ✅ thêm vào đầu file
import numpy as np
import pandas as pd
import joblib
import tensorflow as tf
from tensorflow.keras.models import Model
from tensorflow.keras.layers import (
    Input, LSTM, Dense, Concatenate, Dropout,
    LayerNormalization, Bidirectional
)
from tensorflow.keras.optimizers import Adam
from tensorflow.keras.callbacks import (
    EarlyStopping,
    ModelCheckpoint,
    ReduceLROnPlateau
)
from sklearn.preprocessing import RobustScaler

# ============================================================================
# ✅ GPU MEMORY GROWTH — PHẢI ĐẶT NGAY SAU IMPORT, TRƯỚC MỌI THAO TÁC TF
# ============================================================================
gpus = tf.config.list_physical_devices('GPU')
if gpus:
    try:
        for gpu in gpus:
            tf.config.experimental.set_memory_growth(gpu, True)
    except RuntimeError as e:
        print(e)
tf.keras.backend.clear_session()   # ✅ đúng chỗ: dọn model cũ trong session Colab, chạy 1 lần duy nhất

# ============================================================================
# 0. GOOGLE COLAB & MOUNT DRIVE
# ============================================================================
try:
    from google.colab import files, drive
    IN_COLAB = True
    print("Đang tiến hành Mount Google Drive...")
    drive.mount('/content/drive')
except ImportError:
    IN_COLAB = False

# ============================================================================
# 1. CẤU HÌNH HỆ THỐNG
# ============================================================================
PAIR = "GBPUSD"
MODEL_TAG = "GU_Delta_300step_Optimized_PureLSTM"
DRIVE_DIR = "/content/drive/MyDrive/" if IN_COLAB else "./"
if not os.path.exists(DRIVE_DIR):
    os.makedirs(DRIVE_DIR, exist_ok=True)

time_steps_m5 = 300
time_steps_m15 = 300
time_steps_m30 = 300
time_steps_h1 = 300
n_steps = 4
PIP_SIZE = 0.0001
batch_size = 64

FEATURE_ORDER = [
    'Return', 'Body', 'Range', 'Upper_Wick', 'Lower_Wick',
    'Dist_SMA20', 'Dist_SMA50', 'Rel_Vol', 'Time_Delta'
]
feature_cols = FEATURE_ORDER.copy()

SPREAD_PIPS = 1.8
SLIPPAGE_PIPS = 1.0
MIN_PRED_PIPS = 8.0
RR_RATIO = 1.3
SL_RATIO = 1.0 / RR_RATIO

# ============================================================================
# 2. FEATURE ENGINEERING
# ============================================================================
def extract_stationary_features(df):
    df_out = pd.DataFrame(index=df.index)
    close = df['Close']; open_p = df['Open']; high = df['High']; low = df['Low']
    df_out['Return'] = close.pct_change().fillna(0)
    df_out['Body'] = (close - open_p) / open_p
    df_out['Range'] = (high - low) / open_p
    df_out['Upper_Wick'] = (high - df[['Open', 'Close']].max(axis=1)) / open_p
    df_out['Lower_Wick'] = (df[['Open', 'Close']].min(axis=1) - low) / open_p
    sma20 = close.rolling(window=20, min_periods=20).mean()
    df_out['Dist_SMA20'] = (close - sma20) / sma20
    sma50 = close.rolling(window=50, min_periods=50).mean()
    df_out['Dist_SMA50'] = (close - sma50) / sma50
    vol20 = df_out['Range'].rolling(window=20, min_periods=20).mean()
    df_out['Rel_Vol'] = df_out['Range'] / (vol20 + 1e-8)
    time_diff = df['Datetime'].diff().dt.total_seconds() / 60.0
    df_out['Time_Delta'] = np.log1p(time_diff.fillna(0))
    df_out = df_out[FEATURE_ORDER].replace([np.inf, -np.inf], np.nan).fillna(0.0)
    return df_out

# ============================================================================
# 3. LOAD CSV
# ============================================================================
def load_and_clean_csv(file_path):
    df = pd.read_csv(file_path, sep=r'\s+', header=None,
                     names=['Date', 'Time', 'Open', 'High', 'Low', 'Close', 'Volume'],
                     engine='python')
    df['Datetime'] = pd.to_datetime(
        df['Date'].astype(str) + ' ' + df['Time'].astype(str),
        format='%Y.%m.%d %H:%M', errors='coerce'
    )
    df = df[['Datetime', 'Open', 'High', 'Low', 'Close']].copy()
    for col in ['Open', 'High', 'Low', 'Close']:
        df[col] = pd.to_numeric(df[col], errors='coerce')
    df.dropna(subset=['Datetime'], inplace=True)
    df.sort_values('Datetime', inplace=True)
    df.drop_duplicates(subset=['Datetime'], keep='last', inplace=True)
    df[['Open', 'High', 'Low', 'Close']] = df[['Open', 'High', 'Low', 'Close']].ffill()
    df.dropna(subset=['Open', 'High', 'Low', 'Close'], inplace=True)
    df.reset_index(drop=True, inplace=True)
    return df

# ============================================================================
# 4. UPLOAD DATA
# ============================================================================
if IN_COLAB:
    print("=" * 80)
    print("VUI LÒNG UPLOAD 4 FILE DATASET:")
    for tf_name in ["M5", "M15", "M30", "H1"]:
        print(f"{PAIR}_{tf_name}.csv")
    print("=" * 80)
    files.upload()

# ============================================================================
# 5. LOAD 4 TIMEFRAME
# ============================================================================
df_m5_raw = load_and_clean_csv(f'{PAIR}_M5.csv')
df_m15_raw = load_and_clean_csv(f'{PAIR}_M15.csv')
df_m30_raw = load_and_clean_csv(f'{PAIR}_M30.csv')
df_h1_raw = load_and_clean_csv(f'{PAIR}_H1.csv')
print("\n" + "=" * 80 + "\nDATA SIZE\n" + "=" * 80)
print("M5 :", len(df_m5_raw)); print("M15:", len(df_m15_raw))
print("M30:", len(df_m30_raw)); print("H1 :", len(df_h1_raw))

# ============================================================================
# 6. KIỂM TRA DATETIME
# ============================================================================
for name, df in [("M5", df_m5_raw), ("M15", df_m15_raw), ("M30", df_m30_raw), ("H1", df_h1_raw)]:
    if not df['Datetime'].is_monotonic_increasing:
        raise ValueError(f"{name}: Datetime không tăng dần.")
    if df['Datetime'].duplicated().any():
        raise ValueError(f"{name}: Có duplicate Datetime.")

# ============================================================================
# 7. FEATURE ENGINEERING
# ============================================================================
feat_m5 = extract_stationary_features(df_m5_raw)
feat_m15 = extract_stationary_features(df_m15_raw)
feat_m30 = extract_stationary_features(df_m30_raw)
feat_h1 = extract_stationary_features(df_h1_raw)

# ============================================================================
# 8. TARGET
# ============================================================================
df_h1_raw['Target_Delta'] = df_h1_raw['Close'].shift(-n_steps) - df_h1_raw['Close']

# ============================================================================
# 9. DATAFRAME CÓ DATETIME INDEX
# ============================================================================
data_m5 = feat_m5.set_index(df_m5_raw['Datetime'])
data_m15 = feat_m15.set_index(df_m15_raw['Datetime'])
data_m30 = feat_m30.set_index(df_m30_raw['Datetime'])
data_h1 = feat_h1.set_index(df_h1_raw['Datetime'])
data_h1['Target_Delta'] = df_h1_raw.set_index('Datetime')['Target_Delta']

# ============================================================================
# 10. TRAIN / VALIDATION / TEST SPLIT (3 phần)
# ============================================================================
n_total = len(df_h1_raw)
train_ratio = 0.70
val_ratio = 0.15
train_end = int(n_total * train_ratio)
val_end = int(n_total * (train_ratio + val_ratio))
split_time_train = df_h1_raw.iloc[train_end]['Datetime']
split_time_val = df_h1_raw.iloc[val_end]['Datetime']
print("\n" + "=" * 80 + "\nTRAIN / VALIDATION / TEST SPLIT\n" + "=" * 80)
print("Total H1        :", n_total)
print("train_end idx   :", train_end, "| time:", split_time_train)
print("val_end idx     :", val_end, "| time:", split_time_val)
print(f"Test set (KHÔNG dùng train): {n_total - val_end} nến H1, từ {split_time_val}")

# ============================================================================
# 11. SCALER FEATURE — CHỈ FIT TRÊN TRAIN
# ============================================================================
train_m5 = data_m5[data_m5.index < split_time_train]
train_m15 = data_m15[data_m15.index < split_time_train]
train_m30 = data_m30[data_m30.index < split_time_train]
train_h1 = data_h1[data_h1.index < split_time_train]
scaler_m5 = RobustScaler().fit(train_m5[feature_cols])
scaler_m15 = RobustScaler().fit(train_m15[feature_cols])
scaler_m30 = RobustScaler().fit(train_m30[feature_cols])
scaler_h1 = RobustScaler().fit(train_h1[feature_cols])

# ============================================================================
# 12. TARGET SCALER — FIT CHỈ TRÊN TRAIN
# ============================================================================
target_train_end = train_end - n_steps
if target_train_end <= 0:
    raise ValueError("train_end quá nhỏ so với n_steps.")
df_h1_temp = df_h1_raw.copy()
df_h1_temp['Target_Delta'] = df_h1_temp['Close'].shift(-n_steps) - df_h1_temp['Close']
target_train = df_h1_temp.iloc[:target_train_end].dropna(subset=['Target_Delta'])
scaler_target = RobustScaler(with_centering=False).fit(target_train[['Target_Delta']])

# ============================================================================
# 13. SAVE SCALERS
# ============================================================================
joblib.dump(scaler_m5, os.path.join(DRIVE_DIR, f'scaler_m5_{PAIR}.save'))
joblib.dump(scaler_m15, os.path.join(DRIVE_DIR, f'scaler_m15_{PAIR}.save'))
joblib.dump(scaler_m30, os.path.join(DRIVE_DIR, f'scaler_m30_{PAIR}.save'))
joblib.dump(scaler_h1, os.path.join(DRIVE_DIR, f'scaler_h1_{PAIR}.save'))
joblib.dump(scaler_target, os.path.join(DRIVE_DIR, f'scaler_target_{PAIR}.save'))

# ============================================================================
# 14. SCALE TOÀN BỘ DATA (FLOAT32)
# ============================================================================
data_m5_s = pd.DataFrame(scaler_m5.transform(data_m5[feature_cols]).astype(np.float32),
                         columns=feature_cols, index=data_m5.index)
data_m15_s = pd.DataFrame(scaler_m15.transform(data_m15[feature_cols]).astype(np.float32),
                          columns=feature_cols, index=data_m15.index)
data_m30_s = pd.DataFrame(scaler_m30.transform(data_m30[feature_cols]).astype(np.float32),
                          columns=feature_cols, index=data_m30.index)
data_h1_s = pd.DataFrame(scaler_h1.transform(data_h1[feature_cols]).astype(np.float32),
                         columns=feature_cols, index=data_h1.index)
target_values = data_h1[['Target_Delta']].copy()
target_values_filled = target_values.fillna(0.0)
data_target_s = pd.DataFrame(scaler_target.transform(target_values_filled).astype(np.float32),
                             columns=['Target_Delta'], index=data_h1.index)

# ============================================================================
# 15. SAVE SPLIT INFORMATION
# ============================================================================
split_info = {
    "pair": PAIR, "train_ratio": train_ratio, "val_ratio": val_ratio,
    "train_end_idx": train_end, "val_end_idx": val_end,
    "target_train_end_idx": target_train_end,
    "split_time": split_time_train, "split_time_val": split_time_val,
    "n_steps": n_steps,
    "time_steps_m5": time_steps_m5, "time_steps_m15": time_steps_m15,
    "time_steps_m30": time_steps_m30, "time_steps_h1": time_steps_h1,
    "feature_order": FEATURE_ORDER,
    "target_definition": "H1 Close[t+n_steps] - H1 Close[t]",
    "target_type": "Future_Close_Delta", "pip_size": PIP_SIZE,
    "test_set_definition": "H1 index >= val_end_idx. KHÔNG dùng ở bất kỳ bước Train nào. Backtest PHẢI bắt đầu từ val_end_idx.",
}
joblib.dump(split_info, os.path.join(DRIVE_DIR, f'split_info_{PAIR}.save'))

# ============================================================================
# 16. SAVE SYSTEM CONFIG
# ============================================================================
system_config = {
    "PAIR": PAIR, "MODEL_TAG": MODEL_TAG,
    "time_steps_m5": time_steps_m5, "time_steps_m15": time_steps_m15,
    "time_steps_m30": time_steps_m30, "time_steps_h1": time_steps_h1,
    "n_steps": n_steps, "FEATURE_ORDER": FEATURE_ORDER,
    "target_type": "Future_Close_Delta",
    "target_definition": "H1 Close[t+4] - H1 Close[t]",
    "PIP_SIZE": PIP_SIZE, "SPREAD_PIPS": SPREAD_PIPS,
    "SLIPPAGE_PIPS": SLIPPAGE_PIPS, "MIN_PRED_PIPS": MIN_PRED_PIPS,
    "RR_RATIO": RR_RATIO, "SL_RATIO": SL_RATIO,
    "prediction_time": "After H1 candle t is fully CLOSED",
    "lower_tf_rule": "Use candles with OpenTime < H1_CloseTime",
    "h1_rule": "Use H1 candle t as the latest closed H1 candle",
    "forming_candle": "NOT_ALLOWED"
}
joblib.dump(system_config, os.path.join(DRIVE_DIR, f'system_config_{PAIR}.save'))

# ============================================================================
# 17. ÁNH XẠ INDEX THỜI GIAN ĐỘNG (chỉ lưu end-position, RAM ~60MB)
# ============================================================================
print("\n" + "=" * 80 + "\nĐANG ÁNH XẠ KHỚP INDEX THỜI GIAN...\n" + "=" * 80)

# ✅ thêm .copy() để chắc chắn độc lập với dataframe (không phụ thuộc view)
arr_m5_base = data_m5_s.values.astype(np.float32).copy()
arr_m15_base = data_m15_s.values.astype(np.float32).copy()
arr_m30_base = data_m30_s.values.astype(np.float32).copy()
arr_h1_base = data_h1_s.values.astype(np.float32).copy()
arr_target_base = data_target_s.values.astype(np.float32).copy()

idx_m5_dt = data_m5_s.index.values.astype('datetime64[ns]')
idx_m15_dt = data_m15_s.index.values.astype('datetime64[ns]')
idx_m30_dt = data_m30_s.index.values.astype('datetime64[ns]')
idx_h1_dt = data_h1_s.index.values.astype('datetime64[ns]')
one_hour = np.timedelta64(1, 'h')

m5_end_positions, m15_end_positions, m30_end_positions = [], [], []
h1_end_positions, target_values_list, h1_indices_list = [], [], []

for i in range(time_steps_h1 - 1, len(data_h1_s) - n_steps):
    t_open_h1 = idx_h1_dt[i]
    t_close_h1 = t_open_h1 + one_hour
    pos_m5 = np.searchsorted(idx_m5_dt, t_close_h1, side='left')
    pos_m15 = np.searchsorted(idx_m15_dt, t_close_h1, side='left')
    pos_m30 = np.searchsorted(idx_m30_dt, t_close_h1, side='left')
    if pos_m5 > 0 and pos_m15 > 0 and pos_m30 > 0:
        if not ((t_open_h1 <= idx_m5_dt[pos_m5 - 1] < t_close_h1) and
                (t_open_h1 <= idx_m15_dt[pos_m15 - 1] < t_close_h1) and
                (t_open_h1 <= idx_m30_dt[pos_m30 - 1] < t_close_h1)):
            continue
    if pos_m5 >= time_steps_m5 and pos_m15 >= time_steps_m15 and pos_m30 >= time_steps_m30:
        m5_end_positions.append(pos_m5)
        m15_end_positions.append(pos_m15)
        m30_end_positions.append(pos_m30)
        h1_end_positions.append(i + 1)
        target_values_list.append(arr_target_base[i][0])
        h1_indices_list.append(i)

# ============================================================================
# 18. MẢNG INDEX PHẲNG + DỌN RAM (đúng thời điểm)
# ============================================================================
m5_ends = np.array(m5_end_positions, dtype=np.int32)
m15_ends = np.array(m15_end_positions, dtype=np.int32)
m30_ends = np.array(m30_end_positions, dtype=np.int32)
h1_ends = np.array(h1_end_positions, dtype=np.int32)
y_arr = np.array(target_values_list, dtype=np.float32).reshape(-1, 1)
h1_indices = np.array(h1_indices_list, dtype=np.int32)

print("\n" + "=" * 80 + "\nINDEX SHAPES\n" + "=" * 80)
print("Số lượng mẫu khớp:", len(h1_indices))

# ✅ Dọn RAM — chỉ xóa những biến KHÔNG còn dùng (giữ lại arr_*_base, *_ends, y_arr, h1_indices)
del m5_end_positions, m15_end_positions, m30_end_positions, h1_end_positions
del target_values_list, h1_indices_list
del idx_m5_dt, idx_m15_dt, idx_m30_dt, idx_h1_dt
del data_m5_s, data_m15_s, data_m30_s, data_h1_s, data_target_s
del data_m5, data_m15, data_m30, data_h1
del feat_m5, feat_m15, feat_m30, feat_h1
del df_m5_raw, df_m15_raw, df_m30_raw, df_h1_raw, df_h1_temp
del target_values, target_values_filled
del train_m5, train_m15, train_m30, train_h1, target_train          # ✅ bổ sung
del scaler_m5, scaler_m15, scaler_m30, scaler_h1, scaler_target     # ✅ bổ sung (đã lưu đĩa)
gc.collect()

# ============================================================================
# 19. TRAIN / VALIDATION / TEST SPLIT MASKS
# ============================================================================
train_mask = (h1_indices + n_steps < train_end)
val_mask = (h1_indices >= train_end) & (h1_indices + n_steps < val_end)
test_mask = (h1_indices >= val_end)

# ============================================================================
# 20. SANITY CHECK SPLIT
# ============================================================================
if np.any(h1_indices[train_mask] + n_steps >= train_end):
    raise RuntimeError("CRITICAL: TRAIN TARGET LEAKAGE DETECTED!")
if np.any(h1_indices[train_mask] >= train_end):
    raise RuntimeError("CRITICAL: TRAIN SAMPLE CROSSES VALIDATION!")
if np.any(h1_indices[val_mask] < train_end):
    raise RuntimeError("CRITICAL: VALIDATION SAMPLE CROSSES TRAIN!")
if np.any(h1_indices[val_mask] + n_steps >= val_end):
    raise RuntimeError("CRITICAL: VALIDATION TARGET LEAKAGE INTO TEST DETECTED!")
if np.any(h1_indices[test_mask] < val_end):
    raise RuntimeError("CRITICAL: TEST SAMPLE CROSSES VALIDATION!")

# ============================================================================
# 21. CHỈ SỐ MẪU TRAIN / VAL
# ============================================================================
train_idx_map = np.where(train_mask)[0].astype(np.int32)
val_idx_map = np.where(val_mask)[0].astype(np.int32)
n_train = len(train_idx_map)
n_val = len(val_idx_map)
n_test = int(test_mask.sum())

print("\n" + "=" * 80 + "\nTRAIN / VALIDATION / TEST SAMPLES\n" + "=" * 80)
print("Train samples      :", n_train)
print("Validation samples :", n_val)
print("Test samples       :", n_test, "(giữ riêng cho backtest)")
if n_train == 0: raise RuntimeError("Không có training samples.")
if n_val == 0:   raise RuntimeError("Không có validation samples.")
if n_test == 0:  raise RuntimeError("Không có test samples — kiểm tra lại train_ratio/val_ratio.")  # ✅ bổ sung

# ============================================================================
# 22. VERIFY TARGET BOUNDARY
# ============================================================================
train_max_i = h1_indices[train_mask].max()
val_min_i = h1_indices[val_mask].min()
val_max_i = h1_indices[val_mask].max()
test_min_i = h1_indices[test_mask].min()
print("\n" + "=" * 80 + "\nTARGET BOUNDARY CHECK\n" + "=" * 80)
print("train_end          :", train_end)
print("max train target i :", train_max_i + n_steps)
print("min validation i   :", val_min_i)
print("max val target i   :", val_max_i + n_steps)
print("min test i         :", test_min_i)
if train_max_i + n_steps >= train_end: raise RuntimeError("TARGET LEAKAGE: train chạm validation.")
if val_min_i < train_end:              raise RuntimeError("VALIDATION bắt đầu trước train_end.")
if val_max_i + n_steps >= val_end:     raise RuntimeError("TARGET LEAKAGE: val chạm test.")
if test_min_i < val_end:               raise RuntimeError("TEST bắt đầu trước val_end.")
print("✅ TARGET BOUNDARY OK — Train/Val/Test hoàn toàn tách biệt.")

# ✅ Sau mục 22 mới được xóa h1_indices + masks (đã dùng hết)
del h1_indices, train_mask, val_mask, test_mask
gc.collect()

# ============================================================================
# 23. ✅ GENERATOR YIELD CẢ BATCH (nhanh gấp 32 lần) — KHÔNG còn .batch() ở tf.data
# ============================================================================
def _slice_batch(batch_idx):
    """Trích xuất 4 input + target cho 1 batch, stack sẵn."""
    X_m5 = np.stack([arr_m5_base[m5_ends[idx] - time_steps_m5: m5_ends[idx]] for idx in batch_idx])
    X_m15 = np.stack([arr_m15_base[m15_ends[idx] - time_steps_m15: m15_ends[idx]] for idx in batch_idx])
    X_m30 = np.stack([arr_m30_base[m30_ends[idx] - time_steps_m30: m30_ends[idx]] for idx in batch_idx])
    X_h1 = np.stack([arr_h1_base[h1_ends[idx] - time_steps_h1: h1_ends[idx]] for idx in batch_idx])
    y = y_arr[batch_idx]
    return {"input_m5": X_m5, "input_m15": X_m15, "input_m30": X_m30, "input_h1": X_h1}, y

def train_generator():
    local_indices = train_idx_map.copy()
    np.random.shuffle(local_indices)   # shuffle khác nhau mỗi epoch (generator được gọi lại mỗi epoch)
    for start in range(0, len(local_indices), batch_size):
        yield _slice_batch(local_indices[start:start + batch_size])

def val_generator():
    for start in range(0, len(val_idx_map), batch_size):
        yield _slice_batch(val_idx_map[start:start + batch_size])

# output_signature có batch dim = None (batch cuối có thể ngắn hơn)
output_signature = (
    {
        "input_m5":  tf.TensorSpec(shape=(None, time_steps_m5,  len(feature_cols)), dtype=tf.float32),
        "input_m15": tf.TensorSpec(shape=(None, time_steps_m15, len(feature_cols)), dtype=tf.float32),
        "input_m30": tf.TensorSpec(shape=(None, time_steps_m30, len(feature_cols)), dtype=tf.float32),
        "input_h1":  tf.TensorSpec(shape=(None, time_steps_h1,  len(feature_cols)), dtype=tf.float32),
    },
    tf.TensorSpec(shape=(None, 1), dtype=tf.float32)
)

train_ds = (
    tf.data.Dataset
    .from_generator(train_generator, output_signature=output_signature)
    .prefetch(tf.data.AUTOTUNE)
)
val_ds = (
    tf.data.Dataset
    .from_generator(val_generator, output_signature=output_signature)
    .prefetch(tf.data.AUTOTUNE)
)

# ============================================================================
# 24. DIRECTIONAL HUBER LOSS
# ============================================================================
@tf.keras.utils.register_keras_serializable(package="Custom", name="directional_huber_loss")
def directional_huber_loss(y_true, y_pred, delta=0.15, penalty_weight=2.5):
    error = y_true - y_pred
    abs_error = tf.abs(error)
    huber_loss = tf.where(abs_error <= delta, 0.5 * tf.square(error),
                          delta * (abs_error - 0.5 * delta))
    same_direction = tf.cast(tf.equal(tf.sign(y_true), tf.sign(y_pred)), tf.float32)
    direction_penalty = tf.where(same_direction > 0.5, 1.0, penalty_weight)
    return tf.reduce_mean(huber_loss * direction_penalty)

# ============================================================================
# 25. MODEL BRANCH
# ============================================================================
def build_gradient_stable_lstm_branch(input_shape, name):
    inp = Input(shape=input_shape, name=name)
    x = Bidirectional(LSTM(64, return_sequences=True, unit_forget_bias=True,
                           kernel_initializer='glorot_uniform'))(inp)
    x = LayerNormalization()(x)
    x = Dropout(0.2)(x)
    x = Bidirectional(LSTM(32, return_sequences=False, unit_forget_bias=True,
                           kernel_initializer='glorot_uniform'))(x)
    out = LayerNormalization()(x)
    return inp, out

# ============================================================================
# 26. CREATE MODEL
# ============================================================================
def create_model():
    n_features = len(feature_cols)
    in_m5,  l_m5  = build_gradient_stable_lstm_branch((time_steps_m5,  n_features), "input_m5")
    in_m15, l_m15 = build_gradient_stable_lstm_branch((time_steps_m15, n_features), "input_m15")
    in_m30, l_m30 = build_gradient_stable_lstm_branch((time_steps_m30, n_features), "input_m30")
    in_h1,  l_h1  = build_gradient_stable_lstm_branch((time_steps_h1,  n_features), "input_h1")
    combined = Concatenate()([l_m5, l_m15, l_m30, l_h1])
    dense = Dense(128, activation="relu")(combined)
    dense = LayerNormalization()(dense)
    dense = Dropout(0.2)(dense)
    dense = Dense(64, activation="relu")(dense)
    dense = LayerNormalization()(dense)
    out = Dense(1, name="output")(dense)
    model = Model(inputs=[in_m5, in_m15, in_m30, in_h1], outputs=out)
    model.compile(optimizer=Adam(learning_rate=0.0003, clipnorm=1.0),
                  loss=directional_huber_loss, metrics=["mae"])
    return model

# ============================================================================
# 27. MODEL INSTANCE
# ============================================================================
model = create_model()
print("\n" + "=" * 80 + "\nMODEL SUMMARY\n" + "=" * 80)
model.summary()

# ============================================================================
# 28. MODEL PATH
# ============================================================================
model_path = os.path.join(DRIVE_DIR, f"{MODEL_TAG}.keras")

# ============================================================================
# 29. CALLBACKS — ✅ ĐÃ BỎ clear_session() (không còn phá hủy model giữa chừng)
# ============================================================================
class ClearMemoryCallback(tf.keras.callbacks.Callback):
    def on_epoch_end(self, epoch, logs=None):
        gc.collect()   # chỉ dọn rác Python, KHÔNG động vào TF graph/model

callbacks = [
    EarlyStopping(monitor="val_loss", patience=7, restore_best_weights=True),
    ModelCheckpoint(model_path, monitor="val_loss", save_best_only=True),
    ReduceLROnPlateau(monitor="val_loss", factor=0.5, patience=4, min_lr=1e-6),
    ClearMemoryCallback()
]

# ============================================================================
# 30. TRAIN
# ============================================================================
print("\n" + "=" * 80 + "\nBẮT ĐẦU TRAIN (ĐÃ TỐI ƯU RAM)\n" + "=" * 80)
print(f"PAIR        : {PAIR}")
print(f"MODEL       : {MODEL_TAG}")
print(f"Batch size  : {batch_size}")
print(f"Train       : {n_train}")
print(f"Validation  : {n_val}")
print(f"Test (backtest): {n_test}")
print("=" * 80)

gc.collect()
history = model.fit(
    train_ds,
    epochs=100,
    validation_data=val_ds,
    callbacks=callbacks,
    verbose=1
)

# ============================================================================
# 31. FINAL SAVE
# ============================================================================
model.save(model_path)

# ============================================================================
# 32. HOÀN TẤT
# ============================================================================
print("\n" + "=" * 80 + "\nTRAIN PIPELINE HOÀN TẤT\n" + "=" * 80)
print("Model Path:", model_path)
print(f"⚠️  Backtest PHẢI đọc split_info['val_end_idx'] ({val_end}) làm điểm bắt đầu,")
print(f"    KHÔNG dùng train_end_idx ({train_end}) — nếu không sẽ bị rò rỉ dữ liệu.")
print("=" * 80)