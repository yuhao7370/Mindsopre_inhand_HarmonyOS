---
id: export
step: "05"
title: 导出模型，认清边界
---

# 导出模型，认清边界

## 这一节要做什么

保存 CKPT、导出 MindIR，再把模型读回来对一次结果，同时弄清它为什么还不能直接塞进 HarmonyOS 应用。

## 正文

训练完成后先存 lenet_digits.ckpt，再用一个全零的 [1,1,28,28] float32 张量导出 MindIR。第一次读回模型时还停在 PYNATIVE_MODE，结果直接报错；切到 GRAPH_MODE 后就跑通了。

我们固定拿一张标签为 5 的测试图做检查。训练网络预测 5，读回来的 MindIR 也预测 5，两份 logits 的最大绝对差是 0.0。这说明桌面导出没有改动这张图的计算结果。

这里要注意：HarmonyOS 应用现在加载的是 MindSpore Lite .ms，自定义模型入口还固定要求 float32 NHWC [1,224,224,3]。刚导出的却是桌面 MindIR，输入为 float32 NCHW [1,1,28,28]。格式和张量都对不上，改个扩展名也没用。

目前只走到了桌面 MindIR。仓库和 PATH 里都没有 converter_lite，Lite 转换、API 24 模拟器加载和 arm64 真机推理还没做。要接进应用，还得先转成 MINDIR_LITE，再补齐灰度化、缩放、归一化和 NCHW 排列，最后拿同一批样本核对数值。

### 保存与导出

```text
ms.save_checkpoint(network, "lenet_digits.ckpt")
ms.export(network, Tensor(np.zeros((1, 1, 28, 28), np.float32)),
          file_name="lenet_digits", file_format="MINDIR")
```

### 回载验证

```text
ms.set_context(mode=ms.GRAPH_MODE)
graph_network = nn.GraphCell(ms.load("lenet_digits.mindir"))
exported_logits = graph_network(Tensor(test_x[:1])).asnumpy()
```

## 跑出来的结果

CKPT 是 177,956 B，MindIR 是 188,389 B。样本标签、导出前预测和回载后预测都是 5，logits 最大差 0.0。Lite .ms 转换和 HarmonyOS 端侧运行还没做。
