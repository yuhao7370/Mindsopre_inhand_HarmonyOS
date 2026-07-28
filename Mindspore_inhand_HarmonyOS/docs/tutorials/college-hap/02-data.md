---
id: data
step: "02"
title: 准备本地数据
---

# 准备本地数据

## 这一节要做什么

先把本地 digits 整理成 LeNet 能吃的格式，再切出固定的训练集和测试集。

## 正文

load_digits() 会给出 1797 张图片，像素范围是 0–16，标签是 0–9。脚本先把像素转成 8-bit 灰度，再用 Pillow 放大到 28×28，最后按 (x - 0.5) / 0.5 归一化到 [-1, 1]。

送进模型的是 float32 NCHW [N, 1, 28, 28]，标签用 int32。我们固定随机种子 42，再按标签做 80/20 分层切分，最后拿到 1437 张训练图和 360 张测试图。

NumpySlicesDataset 可以直接接收这些内存数组。训练集会打乱，测试集保持原顺序；batch 大小是 64，最后不满 64 的一批也保留。

### 缩放与归一化

```text
pixels = np.rint(image / 16.0 * 255.0).astype(np.uint8)
canvas = Image.fromarray(pixels, mode="L").resize((28, 28), Image.Resampling.BILINEAR)
normalized = np.asarray(canvas, dtype=np.float32) / 255.0
input_tensor = ((normalized - 0.5) / 0.5)[None, :, :]
```

### 切分与批处理

```text
train_x, test_x, train_y, test_y = train_test_split(
    images, labels, test_size=0.2, random_state=42, stratify=labels
)
train_data = ds.NumpySlicesDataset(
    {"image": train_x, "label": train_y.astype(np.int32)}, shuffle=True
).batch(64, drop_remainder=False)
```

## 跑出来的结果

原图是 [1797, 8, 8]，处理后是 [1797, 1, 28, 28]。其中 1437 张拿来训练，360 张留作测试，整个过程不用下载数据。
