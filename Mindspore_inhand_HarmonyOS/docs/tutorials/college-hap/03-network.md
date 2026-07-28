---
id: network
step: "03"
title: 搭一个 LeNet-5 网络
---

# 搭一个 LeNet-5 网络

## 这一节要做什么

在 MindSpore 里搭一个 LeNet-5 风格的卷积网络，用于十分类。

## 正文

LeNet-5 是 Yann LeCun 在 1998 年提出的手写数字识别网络：先用卷积和池化提取特征、压缩尺寸，再用全连接层分类。这里把原版的 Sigmoid 和平均池化换成了 ReLU 和最大池化，共 44,404 个可训练参数。

```text
class LeNet5(nn.Cell):
    def __init__(self, num_class=10):
        super().__init__()
        self.features = nn.SequentialCell(
            nn.Conv2d(1, 6, 5, pad_mode="valid"), nn.ReLU(), nn.MaxPool2d(2, 2),
            nn.Conv2d(6, 16, 5, pad_mode="valid"), nn.ReLU(), nn.MaxPool2d(2, 2),
        )
        self.classifier = nn.SequentialCell(
            nn.Flatten(),
            nn.Dense(16 * 4 * 4, 120), nn.ReLU(),
            nn.Dense(120, 84), nn.ReLU(),
            nn.Dense(84, num_class),
        )

    def construct(self, x):
        return self.classifier(self.features(x))
```

数据流向：28×28 的图过第一个 5×5 卷积变 6 通道 24×24，池化后 12×12；再过 5×5 卷积变 16 通道 8×8，池化后 4×4；压平成 256 维向量，经 120、84 两层全连接，输出 10 个 logits，最大的那个就是预测数字。

配好损失函数和优化器，就可以训练了：

```text
loss_fn = nn.SoftmaxCrossEntropyWithLogits(sparse=True, reduction="mean")
optimizer = nn.Momentum(network.trainable_params(), learning_rate=0.01, momentum=0.9)
model = ms.Model(network, loss_fn=loss_fn, optimizer=optimizer,
                 metrics={"accuracy": nn.Accuracy()})
```

## 跑出来的结果

网络在 MindSpore 2.9.0 的 CPU 上构建成功，可训练参数 44,404 个。输入是 float32 [N, 1, 28, 28]，输出是 float32 [N, 10]。
