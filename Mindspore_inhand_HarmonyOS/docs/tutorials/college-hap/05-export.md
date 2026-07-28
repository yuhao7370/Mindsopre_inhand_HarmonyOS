---
id: export
step: "05"
title: 导出模型，走向 HarmonyOS
---

# 导出模型，走向 HarmonyOS

## 这一节要做什么

保存 CKPT、导出 MindIR，再把模型读回来验证一次，确认导出没有改变计算结果。

## 正文

要保存两种文件：

- **CKPT（checkpoint）**：只存权重，用于继续训练或加载权重。
- **MindIR**：完整的计算图加权重，是 MindSpore 的跨平台部署格式。

各一行代码。导出 MindIR 时传一个全零的 [1, 1, 28, 28] 张量告诉它输入形状：

```text
ms.save_checkpoint(network, "lenet_mnist.ckpt")
ms.export(network, Tensor(np.zeros((1, 1, 28, 28), np.float32)),
          file_name="lenet_mnist", file_format="MINDIR")
```

然后把 MindIR 读回来，拿同一张测试图和训练中的网络对一次结果：

```text
graph_network = nn.GraphCell(ms.load("lenet_mnist.mindir"))
logits_export = graph_network(Tensor(image)).asnumpy()
```

这一步需要在 `GRAPH_MODE` 下进行，我们整个脚本都跑在静态图模式，直接加载即可。

从桌面模型到 HarmonyOS 应用还差三步：

1. 用 `converter_lite` 把 MindIR 转成 MindSpore Lite 的 `.ms` 模型；
2. 在应用里补齐预处理：灰度化、缩放到 28×28、按均值 0.1307、标准差 0.3081 标准化，和训练时保持一致；
3. 拿同一批测试样本核对端侧和桌面的输出，数值一致后再上线。

## 跑出来的结果

产物在 `artifacts/` 目录：`lenet_mnist.ckpt`（177,956 B）和 `lenet_mnist.mindir`（189,495 B）。验证用一张标签为 7 的测试图：训练网络预测 7，回载的 MindIR 也预测 7，logits 最大绝对差 0.0，导出没有引入数值偏差。
