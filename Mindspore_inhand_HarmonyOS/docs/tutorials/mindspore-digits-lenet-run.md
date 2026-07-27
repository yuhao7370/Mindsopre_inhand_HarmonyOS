# 用 MindSpore 识别手写数字：一次本地实测

2026-07-28，我在一台 Windows 11 电脑上把这条链路跑了一遍：准备数据、
搭网络、训练、评估，最后导出 MindIR。下面保留了可以直接重跑的脚本和命令，
也会说清楚这个模型离 HarmonyOS 端侧运行还差哪些步骤。

## 先说清楚数据集

本机和仓库里都没有 MNIST 的 IDX 文件。为了离线也能跑，我用了
`sklearn.datasets.load_digits()`：scikit-learn 自带的 1797 张 8×8 灰度
手写数字图。训练前，脚本会把它们双线性放大到 28×28。

所以，文中的 98.61% 是 **sklearn digits 测试集准确率，不是 MNIST
测试集准确率**。任务和网络结构很接近经典入门案例，但数据集不是同一个。

## 我用的环境

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

这里还踩了一个环境坑：torch 2.6.0 能正常导入，torchvision 0.22.0 却和它
对不上，报错是 `operator torchvision::nms does not exist`。这和 MindSpore
无关。为了不在版本问题上打转，数据直接从 scikit-learn 读取。

## 复现命令

从项目目录 `Mindspore_inhand_HarmonyOS` 执行：

```powershell
python docs/tutorials/mindspore-digits-lenet.py `
  --epochs 20 `
  --batch-size 64 `
  --learning-rate 0.002 `
  --output-dir .tmp-college-tutorial/verified-artifacts
```

脚本把 MindSpore、NumPy 和数据管线的随机种子都设为 42，再按标签做
80/20 分层切分。最后得到 1437 张训练图和 360 张测试图。

## 1. 把数据整理好

原始像素范围是 0–16。脚本先把它映射成 8-bit 灰度，再放大到 28×28，
最后用 `(x - 0.5) / 0.5` 归一化到 `[-1, 1]`。送进模型的数据是
float32 NCHW `[N, 1, 28, 28]`，标签是 int32。

```python
bundle = load_digits()
images = resize_digits(bundle.images)
labels = bundle.target.astype(np.int32)
train_x, test_x, train_y, test_y = train_test_split(
    images, labels, test_size=0.2, random_state=42, stratify=labels
)
```

## 2. 搭一个 LeNet 风格网络

网络不复杂。前面是两组卷积、ReLU 和池化，后面接三层全连接，一共有
44,404 个可训练参数。这里用了现代项目里更常见的 ReLU 和 MaxPool，
所以它和 1998 年原版 LeNet-5 不完全一样。

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

如果写过 PyTorch，可以按下面这样对照：

| PyTorch | MindSpore |
| --- | --- |
| `torch.nn.Module` | `mindspore.nn.Cell` |
| `forward()` | `construct()` |
| `DataLoader` | `mindspore.dataset` + `batch()` |
| `CrossEntropyLoss` | `SoftmaxCrossEntropyWithLogits` |
| `torch.optim.Adam` | `mindspore.nn.Adam` |

## 3. 跑训练，看结果

损失函数用稀疏标签交叉熵，优化器是 Adam，学习率 0.002，batch size 64，
一共训练 20 轮。每轮结束后，马上用测试集算一次准确率。

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

第一次运行的几行日志：

```text
epoch=01 test_accuracy=0.8028 seconds=0.348
epoch=03 test_accuracy=0.9417 seconds=0.212
epoch=06 test_accuracy=0.9667 seconds=0.212
epoch=14 test_accuracy=0.9833 seconds=0.208
epoch=20 test_accuracy=0.9861 seconds=0.199
```

第一次运行的最终和最好成绩都是 0.986111，也就是 360 张测试图里认对了
355 张。训练用了 4.344 秒，整段脚本共用 4.731 秒。

把脚本移到文档目录后，我又跑了一次。最终准确率是 0.969444，最好成绩
0.983333，训练用了 4.497 秒。两次都超过 96%，但结果没有一模一样。
CPU 算子的细微差异会带来这种波动，看整体趋势更合适。

## 4. 导出后再读回来

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

生成的文件：

| 文件 | 大小 |
| --- | ---: |
| `lenet_digits.ckpt` | 177,956 B |
| `lenet_digits.mindir` | 188,389 B |

我固定拿一张标签为 5 的测试图做检查。导出前预测是 5，MindIR 读回来后
仍然预测 5，两份 logits 的最大绝对差为 0.0。

第一次回载没有成功，因为程序还在 `PYNATIVE_MODE`。错误信息直接要求
GraphMode，切到 `ms.GRAPH_MODE` 后就正常了。最终脚本已经保留了这一步，
重新运行时不用再处理。

## 5. 为什么还不能直接放进 HarmonyOS

现在拿到的是桌面 MindIR，输入为 float32 NCHW `[1,1,28,28]`，输出为
float32 `[1,10]`。HarmonyOS 应用加载的则是 MindSpore Lite `.ms`，
而且现有自定义模型页固定要求 float32 NHWC `[1,224,224,3]`。

两边的格式、通道、尺寸、布局和归一化都对不上，不能直接导入。把
`.mindir` 改名为 `.ms` 也没用。当前仓库和 PATH 里没有 `converter_lite`，
所以流程先停在桌面 MindIR；Lite 转换和 API 24/arm64 端侧验证还没做。

要接进应用，还得把下面几步补上：

1. 使用与运行时匹配的官方 converter_lite 将 MindIR 转为
   `MINDIR_LITE` `.ms`；
2. 核对唯一输入输出的 dtype、shape、名称和字节数；
3. 在 ArkTS 实现相同的灰度化、28×28 缩放、`[-1,1]` 归一化和 NCHW
   排列；
4. 用同一批样本比较 `.mindir` 与 `.ms` 的 logits 和预测类别；
5. 在 API 24 模拟器与目标 arm64 设备实测加载、推理、内存和耗时。
