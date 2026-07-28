---
id: data
step: "02"
title: 读懂 MNIST，喂给模型
---

# 读懂 MNIST，喂给模型

## 这一节要做什么

用 MindSpore 的数据管道读出 IDX 文件，做归一化并打包成 batch。

## 正文

MNIST 每张图 28×28 个像素，每个像素一个字节，取值 0（全黑）到 255（全白）。`MnistDataset` 能直接解析 IDX 文件，`usage="train"` 拿 60,000 张训练图，`usage="test"` 拿 10,000 张测试图。

读出来的图片做三步处理：

1. **Rescale**：像素从 0–255 缩到 0–1。
2. **Normalize**：按 `(x - 0.1307) / 0.3081` 标准化，0.1307 和 0.3081 是 MNIST 训练集的均值和标准差。
3. **HWC2CHW**：从"高×宽×通道"转成"通道×高×宽"，卷积层要求通道维在最前。

标签转成 int32，最后用 `batch(32)` 打包，训练集打乱，测试集保持原顺序。

```text
def build_dataset(data_dir, usage, batch_size, shuffle):
    dataset = ds.MnistDataset(data_dir, usage=usage, shuffle=shuffle)
    dataset = dataset.map(vision.Rescale(1.0 / 255.0, 0), input_columns="image")
    dataset = dataset.map(
        vision.Normalize(mean=[0.1307], std=[0.3081]), input_columns="image"
    )
    dataset = dataset.map(vision.HWC2CHW(), input_columns="image")
    dataset = dataset.map(transforms.TypeCast(ms.int32), input_columns="label")
    return dataset.batch(batch_size, drop_remainder=False)
```

`drop_remainder=False` 表示最后不满 32 的那一批也保留，避免丢掉几百张测试图。

## 跑出来的结果

训练集每轮产出 1,875 个 batch，测试集 313 个。送进模型的图片是 float32、形状 [32, 1, 28, 28]，标签是 int32。
