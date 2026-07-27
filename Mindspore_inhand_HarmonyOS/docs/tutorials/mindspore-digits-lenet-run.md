# MindSpore 手写数字识别：本地复现实验记录

本教程在 2026-07-28 于 Windows 11 本机完成。目标是用 MindSpore 复现
PyTorch 经典入门中的“卷积网络识别手写数字”流程，并留下可重新执行的脚本、
命令、指标和端侧接入边界。

## 真实性说明

本机和仓库内没有真实 MNIST 的 IDX 数据文件。为了让教程完全离线可复现，
实验使用 `sklearn.datasets.load_digits()` 随 scikit-learn 安装的 1797 张
8×8 灰度手写数字图片，并将它们双线性放大到 28×28。

因此，本文中的 98.61% 是 **sklearn digits 测试集准确率，不是 MNIST
测试集准确率**。它复现的是经典入门的任务和网络结构，不冒充标准 MNIST 实验。

## 实测环境

| 项目 | 实测值 |
| --- | --- |
| 系统 | Windows 11 64-bit |
| CPU | AMD Ryzen 9 7845HX |
| Python | 3.11.7 |
| MindSpore | 2.5.0，CPU |
| scikit-learn | 1.3.2 |
| NumPy | 1.26.4 |
| Pillow | 12.1.1 |
| PyTorch | 2.6.0+cpu |

本机 torchvision 0.22.0 与 torch 2.6.0 不匹配，导入时报
`operator torchvision::nms does not exist`，所以实验不依赖
`torchvision.datasets.MNIST`。

## 复现命令

从项目目录 `Mindspore_inhand_HarmonyOS` 执行：

```powershell
python docs/tutorials/mindspore-digits-lenet.py `
  --epochs 20 `
  --batch-size 64 `
  --learning-rate 0.002 `
  --output-dir .tmp-college-tutorial/verified-artifacts
```

脚本固定 MindSpore、NumPy 和数据管线随机种子为 42，并使用分层 80/20
切分。训练集 1437 张，测试集 360 张。

## 1. 数据准备

原始像素范围为 0–16。脚本先映射到 8-bit 灰度，放大到 28×28，再使用
`(x - 0.5) / 0.5` 归一化到 `[-1, 1]`。最终输入为 float32 NCHW
`[N, 1, 28, 28]`，标签为 int32。

```python
bundle = load_digits()
images = resize_digits(bundle.images)
labels = bundle.target.astype(np.int32)
train_x, test_x, train_y, test_y = train_test_split(
    images, labels, test_size=0.2, random_state=42, stratify=labels
)
```

## 2. 构建 LeNet 风格网络

网络由“卷积—ReLU—池化”两组特征提取层和三层全连接分类器组成，共
44,404 个可训练参数。它是现代 LeNet-5 风格实现，不是 1998 年原论文的
逐层复制。

```python
self.features = nn.SequentialCell(
    nn.Conv2d(1, 6, kernel_size=5, pad_mode="valid"),
    nn.ReLU(),
    nn.MaxPool2d(kernel_size=2, stride=2),
    nn.Conv2d(6, 16, kernel_size=5, pad_mode="valid"),
    nn.ReLU(),
    nn.MaxPool2d(kernel_size=2, stride=2),
)
self.classifier = nn.SequentialCell(
    nn.Flatten(),
    nn.Dense(16 * 4 * 4, 120),
    nn.ReLU(),
    nn.Dense(120, 84),
    nn.ReLU(),
    nn.Dense(84, 10),
)
```

常见概念对应关系：

| PyTorch | MindSpore |
| --- | --- |
| `torch.nn.Module` | `mindspore.nn.Cell` |
| `forward()` | `construct()` |
| `DataLoader` | `mindspore.dataset` + `batch()` |
| `CrossEntropyLoss` | `SoftmaxCrossEntropyWithLogits` |
| `torch.optim.Adam` | `mindspore.nn.Adam` |

## 3. 训练和评估

损失函数为稀疏标签交叉熵，优化器为 Adam，学习率 0.002，批大小 64，
训练 20 轮。

```python
loss_fn = nn.SoftmaxCrossEntropyWithLogits(sparse=True, reduction="mean")
optimizer = nn.Adam(network.trainable_params(), learning_rate=0.002)
model = ms.Model(
    network, loss_fn=loss_fn, optimizer=optimizer,
    metrics={"accuracy": nn.Accuracy()},
)
for epoch in range(1, 21):
    model.train(1, train_data, dataset_sink_mode=False)
    metrics = model.eval(test_data, dataset_sink_mode=False)
```

部分实测日志：

```text
epoch=01 test_accuracy=0.8028 seconds=0.348
epoch=03 test_accuracy=0.9417 seconds=0.212
epoch=06 test_accuracy=0.9667 seconds=0.212
epoch=14 test_accuracy=0.9833 seconds=0.208
epoch=20 test_accuracy=0.9861 seconds=0.199
```

首次完整运行的最终/最佳测试准确率均为 0.986111，即 360 张测试图片中
识别正确 355 张；训练耗时 4.344 秒，脚本完整计时 4.731 秒。将脚本移入
本文档目录后再次执行，最终准确率为 0.969444、最佳准确率为 0.983333，
训练耗时 4.497 秒。两次都超过 96%，但 CPU 算子仍会带来轻微波动，因此
教程不把单次最高值当作保证值。

## 4. 保存、导出和回载验证

```python
ms.save_checkpoint(network, "lenet_digits.ckpt")
ms.export(
    network,
    Tensor(np.zeros((1, 1, 28, 28), np.float32)),
    file_name="lenet_digits",
    file_format="MINDIR",
)
ms.set_context(mode=ms.GRAPH_MODE)
graph_network = nn.GraphCell(ms.load("lenet_digits.mindir"))
```

实测产物：

| 文件 | 大小 |
| --- | ---: |
| `lenet_digits.ckpt` | 177,956 B |
| `lenet_digits.mindir` | 188,389 B |

固定测试样本真实标签为 5；导出前预测为 5，MindIR 回载后预测也为 5，
两份 logits 最大绝对差为 0.0。

第一次回载曾在 `PYNATIVE_MODE` 失败，错误明确要求 GraphMode。切换到
`ms.GRAPH_MODE` 后成功，这个排错步骤已保留在最终脚本中。

## 5. HarmonyOS 端侧边界

本次生成的是桌面侧 MindIR，输入 float32 NCHW `[1,1,28,28]`，输出
float32 `[1,10]`。当前 HarmonyOS 应用通过 MindSpore Lite 加载 `.ms`
模型；现有自定义模型页固定要求 float32 NHWC `[1,224,224,3]`。

这两者在格式、通道、尺寸、布局和归一化上均不兼容，不能直接导入，也不能
把 `.mindir` 改名为 `.ms`。当前仓库和 PATH 内没有 `converter_lite`，
所以本次没有声称完成 Lite 转换或 API 24/arm64 端侧验证。

后续真正接入至少需要：

1. 使用与运行时匹配的官方 converter_lite 将 MindIR 转为
   `MINDIR_LITE` `.ms`；
2. 核对唯一输入输出的 dtype、shape、名称和字节数；
3. 在 ArkTS 实现相同的灰度化、28×28 缩放、`[-1,1]` 归一化和 NCHW
   排列；
4. 用同一批样本比较 `.mindir` 与 `.ms` 的 logits 和预测类别；
5. 在 API 24 模拟器与目标 arm64 设备实测加载、推理、内存和耗时。
