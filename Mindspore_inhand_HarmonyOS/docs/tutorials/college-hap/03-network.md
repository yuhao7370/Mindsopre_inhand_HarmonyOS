---
id: network
step: "03"
title: 搭好 LeNet 网络
---

# 搭好 LeNet 网络

## 这一节要做什么

照着熟悉的 PyTorch 思路，在 MindSpore 里搭一个十分类网络。

## 正文

结构很经典：两组卷积、ReLU 和最大池化负责提取特征，后面接 120、84、10 三层全连接，最后输出十类 logits。整个网络有 44,404 个可训练参数。

如果写过 PyTorch，这里很好对照：nn.Module 换成 nn.Cell，forward() 换成 construct()；DataLoader 对应 mindspore.dataset 和 batch()；交叉熵与 Adam 也都有直接对应的类。

这里用的是 ReLU 和 MaxPool，所以更准确地说，它是现代 LeNet-5 风格网络，和 1998 年原版不完全一样。拿它入门卷积分类正合适。

### MindSpore 网络

```text
class LeNet5(nn.Cell):
    def __init__(self):
        super().__init__()
        self.features = nn.SequentialCell(
            nn.Conv2d(1, 6, 5, pad_mode="valid"), nn.ReLU(), nn.MaxPool2d(2, 2),
            nn.Conv2d(6, 16, 5, pad_mode="valid"), nn.ReLU(), nn.MaxPool2d(2, 2)
        )
        self.classifier = nn.SequentialCell(
            nn.Flatten(), nn.Dense(16 * 4 * 4, 120), nn.ReLU(),
            nn.Dense(120, 84), nn.ReLU(), nn.Dense(84, 10)
        )

    def construct(self, x):
        return self.classifier(self.features(x))
```

### 损失与优化器

```text
loss_fn = nn.SoftmaxCrossEntropyWithLogits(sparse=True, reduction="mean")
optimizer = nn.Adam(network.trainable_params(), learning_rate=0.002)
model = ms.Model(network, loss_fn=loss_fn, optimizer=optimizer,
                 metrics={"accuracy": nn.Accuracy()})
```

## 跑出来的结果

网络已经在 MindSpore 2.5.0 CPU 上完成前向、反向和参数更新。输入是 float32 NCHW [N,1,28,28]，输出是 float32 [N,10]。
